import Foundation
import SwiftData

@Model
final class GitHubRepository {
    var id: UUID
    var name: String
    var owner: String
    var url: String
    var isPrivate: Bool
    var defaultBranch: String
    var accessToken: String?
    var lastSync: Date?
    var includedPaths: [String] = [] // Paths to include (empty = all)
    var excludedPaths: [String] = [] // Paths to explicitly exclude

    @Relationship(deleteRule: .cascade, inverse: \MarkdownFile.repository)
    var files: [MarkdownFile] = []

    init(
        id: UUID = UUID(),
        name: String,
        owner: String,
        url: String,
        isPrivate: Bool = false,
        defaultBranch: String = "main",
        accessToken: String? = nil,
        lastSync: Date? = nil,
        includedPaths: [String] = [],
        excludedPaths: [String] = []
    ) {
        self.id = id
        self.name = name
        self.owner = owner
        self.url = url
        self.isPrivate = isPrivate
        self.defaultBranch = defaultBranch
        self.accessToken = accessToken
        self.lastSync = lastSync
        self.includedPaths = includedPaths
        self.excludedPaths = excludedPaths
    }

    /// Check if a file path should be included based on settings
    func shouldIncludePath(_ path: String) -> Bool {
        // If excludedPaths contains this path or its parent, exclude it
        for excluded in excludedPaths {
            if path.hasPrefix(excluded) {
                return false
            }
        }

        // If includedPaths is empty, include everything (except excluded)
        if includedPaths.isEmpty {
            return true
        }

        // Otherwise, check if path matches any included path
        for included in includedPaths {
            if path.hasPrefix(included) {
                return true
            }
        }

        return false
    }

    /// Full repository identifier (owner/name)
    var fullName: String {
        "\(owner)/\(name)"
    }

    /// Returns true if this repository needs authentication
    var requiresAuth: Bool {
        isPrivate && accessToken != nil
    }
}
