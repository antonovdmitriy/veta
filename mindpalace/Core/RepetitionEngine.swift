import Foundation
import SwiftData

struct ReviewStatistics {
    let totalSections: Int
    let reviewedSections: Int
    let newSections: Int
    let reviewedToday: Int
    let currentStreak: Int
    let dailyGoal: Int

    var progress: Double {
        guard totalSections > 0 else { return 0 }
        return Double(reviewedSections) / Double(totalSections)
    }

    var dailyProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(reviewedToday) / Double(dailyGoal))
    }
}

class RepetitionEngine {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Getting Next Section

    /// Returns the next section to review based on priority
    func getNextSection() -> MarkdownSection? {
        let descriptor = FetchDescriptor<MarkdownSection>(
            sortBy: [SortDescriptor(\.id)]
        )

        guard let allSections = try? modelContext.fetch(descriptor) else {
            print("⚠️ RepetitionEngine: Failed to fetch sections")
            return nil
        }

        print("📚 RepetitionEngine: Total sections: \(allSections.count)")

        // Build efficient lookup for leaf sections
        let leafSections = findLeafSections(in: allSections)

        print("🍃 RepetitionEngine: Leaf sections: \(leafSections.count)")

        // If no leaf sections found, fall back to all sections
        let sectionsToConsider = leafSections.isEmpty ? allSections : leafSections

        // Sort by priority
        let sortedSections = sectionsToConsider.sorted { section1, section2 in
            section1.reviewPriority > section2.reviewPriority
        }

        let nextSection = sortedSections.first
        if let section = nextSection {
            print("✅ RepetitionEngine: Selected section '\(section.title)' (level: \(section.level))")
        } else {
            print("❌ RepetitionEngine: No sections available")
        }

        return nextSection
    }

    /// Efficiently find all leaf sections (O(n) instead of O(n²))
    private func findLeafSections(in allSections: [MarkdownSection]) -> [MarkdownSection] {
        // Group sections by file
        var sectionsByFile: [UUID: [MarkdownSection]] = [:]
        for section in allSections {
            guard let fileId = section.file?.id else { continue }
            sectionsByFile[fileId, default: []].append(section)
        }

        var leafSections: [MarkdownSection] = []

        // Process each file separately
        for (_, sections) in sectionsByFile {
            let sortedSections = sections.sorted { $0.orderIndex < $1.orderIndex }

            for (index, section) in sortedSections.enumerated() {
                let isLeaf: Bool
                if index + 1 < sortedSections.count {
                    let nextSection = sortedSections[index + 1]
                    isLeaf = nextSection.level <= section.level
                } else {
                    isLeaf = true // Last section in file
                }

                if isLeaf {
                    leafSections.append(section)
                }
            }
        }

        return leafSections
    }

    /// Returns multiple sections for batch review
    func getNextSections(count: Int) -> [MarkdownSection] {
        let descriptor = FetchDescriptor<MarkdownSection>(
            sortBy: [SortDescriptor(\.id)]
        )

        guard let allSections = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Build efficient lookup for leaf sections
        let leafSections = findLeafSections(in: allSections)

        // If no leaf sections found, fall back to all sections
        let sectionsToConsider = leafSections.isEmpty ? allSections : leafSections

        // Sort by priority
        let sortedSections = sectionsToConsider.sorted { section1, section2 in
            section1.reviewPriority > section2.reviewPriority
        }

        return Array(sortedSections.prefix(count))
    }

    /// Returns sections from a specific repository
    func getSections(for repository: GitHubRepository) -> [MarkdownSection] {
        let descriptor = FetchDescriptor<MarkdownSection>()

        guard let allSections = try? modelContext.fetch(descriptor) else {
            return []
        }

        return allSections.filter { section in
            section.file?.repository?.id == repository.id
        }
    }

    // MARK: - Recording Reviews

    /// Marks a section as reviewed with the given quality
    func markAsReviewed(section: MarkdownSection, quality: Int = 3) {
        let record = RepetitionRecord.createReview(for: section, quality: quality)
        modelContext.insert(record)

        do {
            try modelContext.save()
        } catch {
            print("Error saving review record: \(error)")
        }
    }

    /// Marks multiple sections as reviewed
    func markAsReviewed(sections: [MarkdownSection], quality: Int = 3) {
        for section in sections {
            let record = RepetitionRecord.createReview(for: section, quality: quality)
            modelContext.insert(record)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving review records: \(error)")
        }
    }

    // MARK: - Statistics

    /// Returns current review statistics
    func getStatistics(dailyGoal: Int = Constants.Repetition.defaultDailyGoal) -> ReviewStatistics {
        let sectionDescriptor = FetchDescriptor<MarkdownSection>()
        let recordDescriptor = FetchDescriptor<RepetitionRecord>()

        guard let allSections = try? modelContext.fetch(sectionDescriptor),
              let allRecords = try? modelContext.fetch(recordDescriptor) else {
            return ReviewStatistics(
                totalSections: 0,
                reviewedSections: 0,
                newSections: 0,
                reviewedToday: 0,
                currentStreak: 0,
                dailyGoal: dailyGoal
            )
        }

        let totalSections = allSections.count
        let reviewedSections = allSections.filter { !$0.isNew }.count
        let newSections = allSections.filter { $0.isNew }.count

        // Count unique sections reviewed today
        let today = Calendar.current.startOfDay(for: Date())
        let todaysRecords = allRecords.filter { record in
            Calendar.current.isDate(record.reviewedAt, inSameDayAs: today)
        }
        let uniqueSectionsToday = Set(todaysRecords.compactMap { $0.section?.id })
        let reviewedToday = uniqueSectionsToday.count

        // Calculate streak
        let streak = calculateStreak(from: allRecords)

        return ReviewStatistics(
            totalSections: totalSections,
            reviewedSections: reviewedSections,
            newSections: newSections,
            reviewedToday: reviewedToday,
            currentStreak: streak,
            dailyGoal: dailyGoal
        )
    }

    /// Returns sections reviewed on a specific date
    func getSectionsReviewed(on date: Date) -> [MarkdownSection] {
        let descriptor = FetchDescriptor<RepetitionRecord>()

        guard let allRecords = try? modelContext.fetch(descriptor) else {
            return []
        }

        let recordsOnDate = allRecords.filter { record in
            Calendar.current.isDate(record.reviewedAt, inSameDayAs: date)
        }

        return recordsOnDate.compactMap { $0.section }
    }

    // MARK: - Private Helpers

    private func calculateStreak(from records: [RepetitionRecord]) -> Int {
        guard !records.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Get unique dates when reviews happened
        let reviewDates = Set(records.map { calendar.startOfDay(for: $0.reviewedAt) })
            .sorted(by: >)

        guard let mostRecentDate = reviewDates.first else { return 0 }

        // Check if we reviewed today or yesterday
        let daysSinceLastReview = calendar.dateComponents([.day], from: mostRecentDate, to: today).day ?? 0
        if daysSinceLastReview > 1 {
            return 0 // Streak broken
        }

        var streak = 0
        var currentDate = today

        while reviewDates.contains(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDay
        }

        return streak
    }
}
