import Foundation
import ZIPFoundation

/// Manages local storage of repository assets (images, files, etc.)
class AssetManager {
    static let shared = AssetManager()

    private let fileManager = FileManager.default
    private var baseURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Repositories")
    }

    private init() {
        // Create base directory if needed
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Repository Directory Management

    /// Gets the local directory for a repository
    func repositoryDirectory(owner: String, repo: String) -> URL {
        baseURL.appendingPathComponent("\(owner)/\(repo)")
    }

    /// Creates directory structure for a repository
    func createRepositoryDirectory(owner: String, repo: String) throws {
        let repoDir = repositoryDirectory(owner: owner, repo: repo)
        try fileManager.createDirectory(at: repoDir, withIntermediateDirectories: true)
    }

    /// Clears all assets for a repository
    func clearRepository(owner: String, repo: String) throws {
        let repoDir = repositoryDirectory(owner: owner, repo: repo)
        if fileManager.fileExists(atPath: repoDir.path) {
            try fileManager.removeItem(at: repoDir)
        }
    }

    // MARK: - Archive Extraction

    /// Extracts a zip archive to the repository directory
    func extractArchive(data: Data, owner: String, repo: String) throws -> [URL] {
        // Clear existing files
        try? clearRepository(owner: owner, repo: repo)
        try createRepositoryDirectory(owner: owner, repo: repo)

        let repoDir = repositoryDirectory(owner: owner, repo: repo)
        let tempZipURL = fileManager.temporaryDirectory.appendingPathComponent("\(owner)-\(repo).zip")

        // Write zip data to temp file
        try data.write(to: tempZipURL)

        // Extract zip using ZIPFoundation
        try fileManager.unzipItem(at: tempZipURL, to: repoDir)

        // Clean up temp file
        try? fileManager.removeItem(at: tempZipURL)

        // GitHub archives extract to a subdirectory like "repo-branch-sha"
        // We need to move contents up one level
        let contents = try fileManager.contentsOfDirectory(at: repoDir, includingPropertiesForKeys: nil)
        if contents.count == 1, let extractedDir = contents.first {
            let extractedDirAttributes = try fileManager.attributesOfItem(atPath: extractedDir.path)
            if extractedDirAttributes[.type] as? FileAttributeType == .typeDirectory {
                // Move all files from subdirectory to repo directory
                let files = try fileManager.contentsOfDirectory(at: extractedDir, includingPropertiesForKeys: nil)
                for file in files {
                    let destination = repoDir.appendingPathComponent(file.lastPathComponent)
                    try? fileManager.removeItem(at: destination) // Remove if exists
                    try fileManager.moveItem(at: file, to: destination)
                }
                // Remove empty subdirectory
                try fileManager.removeItem(at: extractedDir)
            }
        }

        // Return list of all extracted files
        return try getAllFiles(in: repoDir)
    }

    // MARK: - File Access

    /// Gets local URL for an asset path
    func localURL(owner: String, repo: String, path: String) -> URL {
        repositoryDirectory(owner: owner, repo: repo).appendingPathComponent(path)
    }

    /// Checks if an asset exists locally
    func assetExists(owner: String, repo: String, path: String) -> Bool {
        let url = localURL(owner: owner, repo: repo, path: path)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Gets all files in a directory recursively
    private func getAllFiles(in directory: URL) throws -> [URL] {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            if let isRegularFile = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile,
               isRegularFile {
                files.append(fileURL)
            }
        }
        return files
    }

    // MARK: - File Categorization

    /// Separates files into markdown and assets
    func categorizeFiles(_ files: [URL]) -> (markdown: [URL], assets: [URL]) {
        var markdown: [URL] = []
        var assets: [URL] = []

        for file in files {
            if file.pathExtension.lowercased() == "md" {
                markdown.append(file)
            } else {
                assets.append(file)
            }
        }

        return (markdown, assets)
    }
}
