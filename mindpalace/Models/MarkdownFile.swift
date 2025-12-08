import Foundation
import SwiftData

@Model
final class MarkdownFile {
    var id: UUID
    var path: String
    var fileName: String
    var content: String?
    var lastUpdated: Date
    var sha: String? // Git SHA for tracking changes

    var repository: GitHubRepository?

    @Relationship(deleteRule: .cascade, inverse: \MarkdownSection.file)
    var sections: [MarkdownSection] = []

    init(
        id: UUID = UUID(),
        path: String,
        fileName: String,
        content: String? = nil,
        lastUpdated: Date = Date(),
        sha: String? = nil,
        repository: GitHubRepository? = nil
    ) {
        self.id = id
        self.path = path
        self.fileName = fileName
        self.content = content
        self.lastUpdated = lastUpdated
        self.sha = sha
        self.repository = repository
    }

    /// Full path in repository including filename
    var fullPath: String {
        path
    }

    /// Returns true if content needs to be fetched
    var needsContent: Bool {
        content == nil
    }

    /// Returns number of sections in this file
    var sectionCount: Int {
        sections.count
    }
}
