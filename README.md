# Mind Palace

A spaced repetition learning app for reviewing markdown notes stored in GitHub repositories.

## Features

- 📚 Import markdown files from GitHub repositories (public and private)
- 🧠 Smart repetition algorithm for effective learning
- 📊 Track your progress and streaks
- 🔄 Sync progress across devices via GitHub Gist
- 📱 Native iOS and macOS apps

## Architecture

- **SwiftUI** for the user interface
- **SwiftData** for local persistence
- **GitHub API** for fetching repositories and files
- **MarkdownUI** for rendering markdown content

## Project Structure

```
MindPalace/
├── Shared/              # Shared code for iOS and macOS
│   ├── Models/          # Data models (SwiftData)
│   ├── Services/        # Business logic services
│   ├── Core/            # Core algorithms (repetition engine)
│   └── Utilities/       # Helpers and extensions
├── iOS/                 # iOS-specific code
│   ├── Views/           # SwiftUI views
│   └── ViewModels/      # View models
└── macOS/              # macOS-specific code (future)
```

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### Installation

1. Clone the repository
2. Open `MindPalace.xcodeproj` in Xcode
3. Build and run

### Adding Repositories

1. Go to the "Repositories" tab
2. Tap the "+" button
3. Enter your GitHub repository URL
4. For private repos, provide a Personal Access Token
5. The app will automatically fetch all markdown files

## Development Status

Current version: **0.1.0 (MVP in development)**

### Completed
- ✅ Data models with SwiftData
- ✅ GitHub API integration
- ✅ Markdown parsing
- ✅ Basic repetition algorithm
- ✅ iOS UI (Study, Repositories, Statistics, Settings)

### TODO
- ⏳ GitHub OAuth authentication
- ⏳ GitHub Gist synchronization
- ⏳ Image caching and optimization
- ⏳ macOS version
- ⏳ Advanced spaced repetition (SM-2 algorithm)
- ⏳ Search and filtering
- ⏳ Export/import functionality

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
