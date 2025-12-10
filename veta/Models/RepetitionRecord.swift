import Foundation
import SwiftData

@Model
final class RepetitionRecord {
    var id: UUID
    var reviewedAt: Date
    var ease: Double // For future spaced repetition (SM-2)
    var quality: Int // User rating 0-5 (0=worst, 5=perfect)

    var section: MarkdownSection?

    init(
        id: UUID = UUID(),
        reviewedAt: Date = Date(),
        ease: Double = 2.5,
        quality: Int = 3,
        section: MarkdownSection? = nil
    ) {
        self.id = id
        self.reviewedAt = reviewedAt
        self.ease = ease
        self.quality = quality
        self.section = section
    }

    /// Creates a record for successful review
    static func createReview(for section: MarkdownSection, quality: Int = 3) -> RepetitionRecord {
        RepetitionRecord(
            reviewedAt: Date(),
            ease: 2.5,
            quality: quality,
            section: section
        )
    }
}

// MARK: - Codable for Gist sync
extension RepetitionRecord {
    struct SyncData: Codable {
        let sectionSyncId: String
        let reviewedAt: Date
        let ease: Double
        let quality: Int
    }

    var syncData: SyncData {
        SyncData(
            sectionSyncId: section?.syncId ?? "",
            reviewedAt: reviewedAt,
            ease: ease,
            quality: quality
        )
    }
}
