import Foundation
import SwiftData

@Model
final class UserSettings {
    var id: UUID
    var githubToken: String?
    var autoSync: Bool
    var dailyGoal: Int // Number of sections to review per day
    var showImages: Bool
    var syncGistId: String? // ID of the gist used for syncing

    init(
        id: UUID = UUID(),
        githubToken: String? = nil,
        autoSync: Bool = true,
        dailyGoal: Int = 10,
        showImages: Bool = true,
        syncGistId: String? = nil
    ) {
        self.id = id
        self.githubToken = githubToken
        self.autoSync = autoSync
        self.dailyGoal = dailyGoal
        self.showImages = showImages
        self.syncGistId = syncGistId
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
