import Foundation
import SwiftData

@Model
final class MarkdownSection {
    var id: UUID
    var title: String
    var content: String
    var level: Int // H1=1, H2=2, H3=3, etc.
    var lineStart: Int
    var lineEnd: Int
    var orderIndex: Int // Position in file
    var isIgnored: Bool = false // User chose to ignore this section
    var isFavoriteSection: Bool = false // User marked this specific section as favorite

    var file: MarkdownFile?

    @Relationship(deleteRule: .cascade, inverse: \RepetitionRecord.section)
    var repetitionRecords: [RepetitionRecord] = []

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        level: Int,
        lineStart: Int,
        lineEnd: Int,
        orderIndex: Int = 0,
        file: MarkdownFile? = nil,
        isIgnored: Bool = false,
        isFavoriteSection: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.level = level
        self.lineStart = lineStart
        self.lineEnd = lineEnd
        self.orderIndex = orderIndex
        self.file = file
        self.isIgnored = isIgnored
        self.isFavoriteSection = isFavoriteSection
    }

    /// Unique identifier for syncing across devices
    var syncId: String {
        guard let file = file,
              let repo = file.repository else {
            return id.uuidString
        }
        return "\(repo.fullName):\(file.path):\(title):\(lineStart)"
    }

    /// Last time this section was reviewed
    var lastReviewDate: Date? {
        repetitionRecords.map(\.reviewedAt).max()
    }

    /// Total number of times this section was reviewed
    var reviewCount: Int {
        repetitionRecords.count
    }

    /// Returns true if never reviewed
    var isNew: Bool {
        repetitionRecords.isEmpty
    }

    /// Check if this section is a leaf node (has no children)
    func isLeafSection(in allSections: [MarkdownSection]) -> Bool {
        guard let file = file else { return true }

        let fileSections = allSections
            .filter { $0.file?.id == file.id }
            .sorted { $0.orderIndex < $1.orderIndex }

        guard let currentIndex = fileSections.firstIndex(where: { $0.id == self.id }) else {
            return true
        }

        // Check if next section has higher level (is a child)
        if currentIndex + 1 < fileSections.count {
            let nextSection = fileSections[currentIndex + 1]
            return nextSection.level <= level // No children if next is same or lower level
        }

        return true // Last section in file is always a leaf
    }

    /// Priority for review (higher = more urgent)
    var reviewPriority: Double {
        var basePriority: Double

        if isNew {
            basePriority = 1000.0 // New sections have highest priority
        } else if let lastReview = lastReviewDate {
            // Calculate days since last review
            basePriority = Date().timeIntervalSince(lastReview) / 86400.0
        } else {
            basePriority = 1000.0
        }

        // Boost for favorites (helps them return to top faster after review)
        if isFavoriteSection {
            basePriority *= 1.5 // 50% boost for favorite sections
        } else if isFromFavoriteFolder {
            basePriority *= 1.3 // 30% boost for favorite folders
        }

        return basePriority
    }

    /// Check if this section is from a favorite folder
    var isFromFavoriteFolder: Bool {
        guard let file = file,
              let repository = file.repository else {
            return false
        }

        let filePath = file.path
        return repository.favoritePaths.contains { favPath in
            filePath == favPath || filePath.hasPrefix(favPath + "/")
        }
    }

    /// Get parent section (section with lower level that comes before this one)
    /// Returns nil only if this is level 0 (full document view)
    func getParentSection(from allSections: [MarkdownSection]) -> MarkdownSection? {
        guard let file = file else { return nil }

        // Level 0 means full document - no parent
        if level == 0 { return nil }

        // Get all sections from the same file, sorted by order
        let fileSections = allSections
            .filter { $0.file?.id == file.id }
            .sorted { $0.orderIndex < $1.orderIndex }

        // Find this section's index
        guard let currentIndex = fileSections.firstIndex(where: { $0.id == self.id }) else {
            return nil
        }

        // Look backwards for first section with level < current level
        for i in (0..<currentIndex).reversed() {
            let section = fileSections[i]
            if section.level < level {
                return section
            }
        }

        // If no parent found but level > 1, can still go to level 0 (full document)
        // Return a special marker: the first section in the file with level 0
        // We'll handle this in the ViewModel
        return nil
    }

    /// Get content with all child sections included (for context view)
    func getContentWithChildren(from allSections: [MarkdownSection]) -> String {
        guard let file = file else { return content }

        let fileSections = allSections
            .filter { $0.file?.id == file.id }
            .sorted { $0.orderIndex < $1.orderIndex }

        guard let currentIndex = fileSections.firstIndex(where: { $0.id == self.id }) else {
            return content
        }

        var combinedContent = "# \(title)\n\n\(content)"

        // Add all child sections (sections with higher level that come after)
        for i in (currentIndex + 1)..<fileSections.count {
            let section = fileSections[i]
            // Stop if we encounter same or lower level
            if section.level <= level {
                break
            }
            // Add child section
            let prefix = String(repeating: "#", count: section.level)
            combinedContent += "\n\n\(prefix) \(section.title)\n\n\(section.content)"
        }

        return combinedContent
    }
}
