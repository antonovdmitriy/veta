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
    var autoSync: Bool
    var dailyGoal: Int // Number of sections to review per day
    var showImages: Bool
    var syncGistId: String? // ID of the gist used for syncing
    var themeRawValue: String = AppTheme.system.rawValue // Store theme as raw value with default

    var theme: AppTheme {
        get { AppTheme(rawValue: themeRawValue) ?? .system }
        set { themeRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        githubToken: String? = nil,
        autoSync: Bool = true,
        dailyGoal: Int = 10,
        showImages: Bool = true,
        syncGistId: String? = nil,
        theme: AppTheme = .system
    ) {
        self.id = id
        self.githubToken = githubToken
        self.autoSync = autoSync
        self.dailyGoal = dailyGoal
        self.showImages = showImages
        self.syncGistId = syncGistId
        self.themeRawValue = theme.rawValue
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
