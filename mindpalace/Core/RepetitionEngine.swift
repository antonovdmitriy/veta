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
    private var cachedInterleavedSections: [MarkdownSection] = []
    private var cacheTimestamp: Date?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Get user settings or return defaults
    private func getUserSettings() -> UserSettings {
        let descriptor = FetchDescriptor<UserSettings>()
        if let settings = try? modelContext.fetch(descriptor).first {
            return settings
        }
        // Return default settings if none exist
        return UserSettings()
    }

    // MARK: - Getting Next Section

    /// Returns the next section to review based on priority
    func getNextSection() -> MarkdownSection? {
        let settings = getUserSettings()
        let cacheValidityDuration = TimeInterval(settings.cacheDurationSeconds)

        // Check if cache is valid and has sections
        if let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration,
           !cachedInterleavedSections.isEmpty {
            // Return first section and remove it from cache
            return cachedInterleavedSections.removeFirst()
        }

        // Cache is invalid or empty, rebuild it
        rebuildCache()

        // Return first section from fresh cache
        if !cachedInterleavedSections.isEmpty {
            return cachedInterleavedSections.removeFirst()
        }

        return nil
    }

    private func rebuildCache() {
        let settings = getUserSettings()
        let descriptor = FetchDescriptor<MarkdownSection>(
            sortBy: [SortDescriptor(\.id)]
        )

        guard let allSections = try? modelContext.fetch(descriptor) else {
            cachedInterleavedSections = []
            return
        }

        // Filter sections based on repository path settings and ignored status
        let filteredSections = allSections.filter { section in
            guard let file = section.file,
                  let repository = file.repository else {
                return false
            }
            // Skip ignored sections
            if section.isIgnored {
                return false
            }
            return repository.shouldIncludePath(file.path)
        }

        // Build efficient lookup for leaf sections
        let leafSections = findLeafSections(in: filteredSections)

        // If no leaf sections found, fall back to filtered sections
        let sectionsToConsider = leafSections.isEmpty ? filteredSections : leafSections

        // Separate favorites from regular sections
        // Use custom multipliers from settings
        var favoriteSections = sectionsToConsider.filter { section in
            section.isFavoriteSection || section.isFromFavoriteFolder
        }.sorted {
            $0.calculateReviewPriority(
                favoriteBoost: settings.favoriteBoostMultiplier,
                favoriteFolderBoost: settings.favoriteFolderBoostMultiplier
            ) > $1.calculateReviewPriority(
                favoriteBoost: settings.favoriteBoostMultiplier,
                favoriteFolderBoost: settings.favoriteFolderBoostMultiplier
            )
        }

        var regularSections = sectionsToConsider.filter { section in
            !section.isFavoriteSection && !section.isFromFavoriteFolder
        }.sorted {
            $0.calculateReviewPriority(
                favoriteBoost: settings.favoriteBoostMultiplier,
                favoriteFolderBoost: settings.favoriteFolderBoostMultiplier
            ) > $1.calculateReviewPriority(
                favoriteBoost: settings.favoriteBoostMultiplier,
                favoriteFolderBoost: settings.favoriteFolderBoostMultiplier
            )
        }

        // Shuffle within priority groups to add variety (use setting for top count)
        let shuffleCount = settings.topSectionsShuffleCount
        if favoriteSections.count > 1 {
            let topCount = min(shuffleCount, favoriteSections.count)
            let topFavorites = Array(favoriteSections.prefix(topCount)).shuffled()
            let rest = Array(favoriteSections.dropFirst(topCount))
            favoriteSections = topFavorites + rest
        }

        if regularSections.count > 1 {
            let topCount = min(shuffleCount, regularSections.count)
            let topRegular = Array(regularSections.prefix(topCount)).shuffled()
            let rest = Array(regularSections.dropFirst(topCount))
            regularSections = topRegular + rest
        }

        // Weighted random selection (use setting for favorite weight)
        cachedInterleavedSections = weightedRandomInterleave(
            favorites: favoriteSections,
            regular: regularSections,
            favoriteWeight: settings.favoriteSectionWeight
        )
        cacheTimestamp = Date()
    }

    /// Weighted random interleave: randomly select from favorites or regular based on weight
    /// Example: favoriteWeight=0.6 means 60% chance to pick favorite, 40% regular
    private func weightedRandomInterleave(
        favorites: [MarkdownSection],
        regular: [MarkdownSection],
        favoriteWeight: Double
    ) -> [MarkdownSection] {
        var result: [MarkdownSection] = []
        var favIndex = 0
        var regIndex = 0

        // Continue until we've used all sections
        while favIndex < favorites.count || regIndex < regular.count {
            let hasFavorites = favIndex < favorites.count
            let hasRegular = regIndex < regular.count

            if hasFavorites && hasRegular {
                // Both available - use weighted random
                let randomValue = Double.random(in: 0..<1)
                if randomValue < favoriteWeight {
                    result.append(favorites[favIndex])
                    favIndex += 1
                } else {
                    result.append(regular[regIndex])
                    regIndex += 1
                }
            } else if hasFavorites {
                // Only favorites left
                result.append(favorites[favIndex])
                favIndex += 1
            } else if hasRegular {
                // Only regular left
                result.append(regular[regIndex])
                regIndex += 1
            }
        }

        return result
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

                if isLeaf && !shouldSkipSection(section) {
                    leafSections.append(section)
                }
            }
        }

        return leafSections
    }

    /// Check if section should be skipped (e.g., table of contents, empty sections)
    private func shouldSkipSection(_ section: MarkdownSection) -> Bool {
        let settings = getUserSettings()
        let title = section.title.lowercased()
        let content = section.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip sections with TOC-like titles
        let tocTitles = [
            "table of contents",
            "содержание",
            "оглавление",
            "toc",
            "contents",
            "index"
        ]

        for tocTitle in tocTitles {
            if title.contains(tocTitle) {
                return true
            }
        }

        // Skip sections that are too short (use setting for minimum length)
        if content.count < settings.minimumContentLength {
            return true
        }

        // Skip sections that are mostly links (use setting for link ratio threshold)
        let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if lines.count > 3 {
            let linkLines = lines.filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("-") || trimmed.hasPrefix("*") || trimmed.hasPrefix("[")
            }
            let linkRatio = Double(linkLines.count) / Double(lines.count)
            if linkRatio > settings.linkRatioThreshold {
                return true
            }
        }

        return false
    }

    /// Returns multiple sections for batch review
    func getNextSections(count: Int) -> [MarkdownSection] {
        let descriptor = FetchDescriptor<MarkdownSection>(
            sortBy: [SortDescriptor(\.id)]
        )

        guard let allSections = try? modelContext.fetch(descriptor) else {
            return []
        }

        // Filter sections based on repository path settings and ignored status
        let filteredSections = allSections.filter { section in
            guard let file = section.file,
                  let repository = file.repository else {
                return false
            }
            // Skip ignored sections
            if section.isIgnored {
                return false
            }
            return repository.shouldIncludePath(file.path)
        }

        // Build efficient lookup for leaf sections
        let leafSections = findLeafSections(in: filteredSections)

        // If no leaf sections found, fall back to filtered sections
        let sectionsToConsider = leafSections.isEmpty ? filteredSections : leafSections

        // Separate favorites from regular sections
        var favoriteSections = sectionsToConsider.filter { section in
            section.isFavoriteSection || section.isFromFavoriteFolder
        }.sorted { $0.reviewPriority > $1.reviewPriority }

        var regularSections = sectionsToConsider.filter { section in
            !section.isFavoriteSection && !section.isFromFavoriteFolder
        }.sorted { $0.reviewPriority > $1.reviewPriority }

        // Shuffle within priority groups to add variety (shuffle top 50 of each)
        if favoriteSections.count > 1 {
            let topCount = min(50, favoriteSections.count)
            let topFavorites = Array(favoriteSections.prefix(topCount)).shuffled()
            let rest = Array(favoriteSections.dropFirst(topCount))
            favoriteSections = topFavorites + rest
        }

        if regularSections.count > 1 {
            let topCount = min(50, regularSections.count)
            let topRegular = Array(regularSections.prefix(topCount)).shuffled()
            let rest = Array(regularSections.dropFirst(topCount))
            regularSections = topRegular + rest
        }

        // Weighted random selection: 60% favorites, 40% regular
        let interleavedSections = weightedRandomInterleave(
            favorites: favoriteSections,
            regular: regularSections,
            favoriteWeight: 0.6
        )

        return Array(interleavedSections.prefix(count))
    }

    /// Returns sections from a specific repository
    func getSections(for repository: GitHubRepository) -> [MarkdownSection] {
        let descriptor = FetchDescriptor<MarkdownSection>()

        guard let allSections = try? modelContext.fetch(descriptor) else {
            return []
        }

        return allSections.filter { section in
            guard section.file?.repository?.id == repository.id,
                  let file = section.file else {
                return false
            }
            return repository.shouldIncludePath(file.path)
        }
    }

    // MARK: - Recording Reviews

    /// Marks a section as reviewed with the given quality
    func markAsReviewed(section: MarkdownSection, quality: Int = 3) {
        let record = RepetitionRecord.createReview(for: section, quality: quality)
        modelContext.insert(record)

        do {
            try modelContext.save()
            // Don't invalidate cache immediately - let it expire naturally
            // This allows preloaded sections to continue working
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
    func getStatistics() -> ReviewStatistics {
        let settings = getUserSettings()
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
                dailyGoal: settings.dailyGoal
            )
        }

        // Filter sections based on repository path settings and ignored status
        let filteredSections = allSections.filter { section in
            guard let file = section.file,
                  let repository = file.repository else {
                return false
            }
            // Skip ignored sections
            if section.isIgnored {
                return false
            }
            return repository.shouldIncludePath(file.path)
        }

        let totalSections = filteredSections.count
        let reviewedSections = filteredSections.filter { !$0.isNew }.count
        let newSections = filteredSections.filter { $0.isNew }.count

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
            dailyGoal: settings.dailyGoal
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
