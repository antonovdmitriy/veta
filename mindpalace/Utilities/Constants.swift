import Foundation

enum Constants {
    // MARK: - GitHub API
    enum GitHub {
        static let baseURL = "https://api.github.com"
        static let rawContentURL = "https://raw.githubusercontent.com"
        static let oauthURL = "https://github.com/login/oauth/authorize"
        static let tokenURL = "https://github.com/login/oauth/access_token"

        // OAuth scopes needed
        static let scopes = ["repo", "gist"]

        // Rate limiting
        static let maxRequestsPerHour = 5000
    }

    // MARK: - Gist
    enum Gist {
        static let progressFileName = "mindpalace_progress.json"
        static let gistDescription = "Mind Palace - Learning Progress Sync"
    }

    // MARK: - Markdown
    enum Markdown {
        static let supportedExtensions = ["md", "markdown"]
        static let headingLevels = 1...6

        // Image patterns
        static let imageExtensions = ["png", "jpg", "jpeg", "gif", "svg", "webp"]
    }

    // MARK: - Storage
    enum Storage {
        static let containerName = "MindPalaceContainer"
        static let keychainService = "com.mindpalace.app"
    }

    // MARK: - Repetition
    enum Repetition {
        static let defaultDailyGoal = 10
        static let defaultEaseFactor = 2.5
        static let minEaseFactor = 1.3
        static let maxEaseFactor = 3.0
    }

    // MARK: - UI
    enum UI {
        static let cardCornerRadius: CGFloat = 12
        static let cardPadding: CGFloat = 16
        static let animationDuration: Double = 0.3
    }
}
