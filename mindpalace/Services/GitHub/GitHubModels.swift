import Foundation

// MARK: - GitHub API Response Models

struct GitHubContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let url: String
    let htmlUrl: String
    let gitUrl: String
    let downloadUrl: String?
    let type: ContentType

    enum ContentType: String, Codable {
        case file = "file"
        case dir = "dir"
        case symlink = "symlink"
    }

    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, url, type
        case htmlUrl = "html_url"
        case gitUrl = "git_url"
        case downloadUrl = "download_url"
    }
}

struct GitHubRepositoryResponse: Codable {
    let id: Int
    let name: String
    let fullName: String
    let owner: GitHubUser
    let `private`: Bool
    let htmlUrl: String
    let description: String?
    let defaultBranch: String

    enum CodingKeys: String, CodingKey {
        case id, name, owner, description
        case fullName = "full_name"
        case `private` = "private"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
    }
}

struct GitHubUser: Codable {
    let login: String
    let id: Int
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}

struct GitHubError: Codable, Error {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}

struct GitHubRateLimit: Codable {
    let resources: Resources

    struct Resources: Codable {
        let core: RateLimit
    }

    struct RateLimit: Codable {
        let limit: Int
        let remaining: Int
        let reset: TimeInterval
        let used: Int
    }
}

// MARK: - Request/Response helpers

enum GitHubAPIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case notFound
    case rateLimitExceeded(resetDate: Date)
    case networkError(Error)
    case decodingError(Error)
    case unknownError(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL"
        case .unauthorized:
            return "Unauthorized. Please check your access token."
        case .notFound:
            return "Repository or file not found"
        case .rateLimitExceeded(let resetDate):
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            let timeString = formatter.string(from: resetDate)

            return """
            GitHub API rate limit exceeded.

            Without a token: 60 requests/hour
            With a token: 5,000 requests/hour

            Limit resets at \(timeString)

            Add a GitHub Personal Access Token in Settings to increase your rate limit.
            """
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unknownError(let statusCode):
            return "Unknown error (status code: \(statusCode))"
        }
    }
}
