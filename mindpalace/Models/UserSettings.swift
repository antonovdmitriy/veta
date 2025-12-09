import Foundation
import SwiftData

enum AppTheme: String, Codable {
    case system
    case light
    case dark
}

@Model
final class UserSettings {
    var id: UUID
    var githubToken: String?
    var dailyGoal: Int // Number of sections to review per day
    var syncGistId: String? // ID of the gist used for syncing
    var themeRawValue: String = AppTheme.system.rawValue // Store theme as raw value with default

    // Repetition algorithm settings
    var favoriteBoostMultiplier: Double = 1.5
    var favoriteFolderBoostMultiplier: Double = 1.3
    var favoriteSectionWeight: Double = 0.6
    var minimumContentLength: Int = 50
    var linkRatioThreshold: Double = 0.7
    var topSectionsShuffleCount: Int = 50
    var cacheDurationSeconds: Int = 30

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRawValue) ?? .system }
        set { themeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        githubToken: String? = nil,
        dailyGoal: Int = 10,
        syncGistId: String? = nil,
        theme: AppTheme = .system,
        favoriteBoostMultiplier: Double = 1.5,
        favoriteFolderBoostMultiplier: Double = 1.3,
        favoriteSectionWeight: Double = 0.6,
        minimumContentLength: Int = 50,
        linkRatioThreshold: Double = 0.7,
        topSectionsShuffleCount: Int = 50,
        cacheDurationSeconds: Int = 30
    ) {
        self.id = id
        self.githubToken = githubToken
        self.dailyGoal = dailyGoal
        self.syncGistId = syncGistId
        self.themeRawValue = theme.rawValue
        self.favoriteBoostMultiplier = favoriteBoostMultiplier
        self.favoriteFolderBoostMultiplier = favoriteFolderBoostMultiplier
        self.favoriteSectionWeight = favoriteSectionWeight
        self.minimumContentLength = minimumContentLength
        self.linkRatioThreshold = linkRatioThreshold
        self.topSectionsShuffleCount = topSectionsShuffleCount
        self.cacheDurationSeconds = cacheDurationSeconds
    }

    /// Returns true if user is authenticated with GitHub
    var isAuthenticated: Bool {
        githubToken != nil && !githubToken!.isEmpty
    }

    /// Returns true if sync is configured
    var isSyncConfigured: Bool {
        isAuthenticated && syncGistId != nil
    }
}
