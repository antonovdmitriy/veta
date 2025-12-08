import Foundation

@MainActor
class GitHubService: Sendable {
    private let urlSession: URLSession
    private var token: String?

    init(token: String? = nil, urlSession: URLSession = .shared) {
        self.token = token
        self.urlSession = urlSession
    }

    // MARK: - Authentication

    func setToken(_ token: String) {
        self.token = token
    }

    // MARK: - Repository Operations

    /// Fetches repository information
    func getRepository(owner: String, name: String) async throws -> GitHubRepositoryResponse {
        let url = URL(string: "\(Constants.GitHub.baseURL)/repos/\(owner)/\(name)")!
        return try await performRequest(url: url)
    }

    /// Lists all markdown files in a repository recursively
    func listMarkdownFiles(owner: String, repo: String, path: String = "") async throws -> [GitHubContent] {
        var allFiles: [GitHubContent] = []
        let contents = try await getContents(owner: owner, repo: repo, path: path)

        for content in contents {
            if content.type == .file && content.name.isMarkdownFile {
                allFiles.append(content)
            } else if content.type == .dir {
                // Recursively get files from subdirectories
                let subFiles = try await listMarkdownFiles(owner: owner, repo: repo, path: content.path)
                allFiles.append(contentsOf: subFiles)
            }
        }

        return allFiles
    }

    /// Gets contents of a directory or file
    func getContents(owner: String, repo: String, path: String) async throws -> [GitHubContent] {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let urlString = "\(Constants.GitHub.baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)"
        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL
        }

        return try await performRequest(url: url)
    }

    /// Downloads raw content of a file
    func downloadFileContent(owner: String, repo: String, path: String, ref: String = "main") async throws -> String {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let urlString = "\(Constants.GitHub.rawContentURL)/\(owner)/\(repo)/\(ref)/\(encodedPath)"
        guard let url = URL(string: urlString) else {
            throw GitHubAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await urlSession.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.unknownError(statusCode: -1)
        }

        try validateResponse(httpResponse)

        guard let content = String(data: data, encoding: .utf8) else {
            throw GitHubAPIError.decodingError(NSError(domain: "UTF8Decoding", code: -1))
        }

        return content
    }

    // MARK: - Rate Limiting

    func getRateLimit() async throws -> GitHubRateLimit {
        let url = URL(string: "\(Constants.GitHub.baseURL)/rate_limit")!
        return try await performRequest(url: url)
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await urlSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubAPIError.unknownError(statusCode: -1)
            }

            try validateResponse(httpResponse)

            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch let error as GitHubAPIError {
            throw error
        } catch let error as DecodingError {
            throw GitHubAPIError.decodingError(error)
        } catch {
            throw GitHubAPIError.networkError(error)
        }
    }

    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299:
            return
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            // Check if it's rate limit
            if let resetTime = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
               let timestamp = TimeInterval(resetTime) {
                let resetDate = Date(timeIntervalSince1970: timestamp)
                throw GitHubAPIError.rateLimitExceeded(resetDate: resetDate)
            }
            throw GitHubAPIError.unauthorized
        case 404:
            throw GitHubAPIError.notFound
        default:
            throw GitHubAPIError.unknownError(statusCode: response.statusCode)
        }
    }
}
