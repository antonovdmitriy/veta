# Veta

**Veta** is an iOS app for effective learning and retention of knowledge from your GitHub markdown notes.

## Why Veta?

Do you store your study notes, learning materials, or technical documentation in markdown files on GitHub? Veta transforms these notes into interactive study cards using spaced repetition algorithm.

**The Problem:** Notes are stored in repositories but aren't reviewed systematically — knowledge fades away.

**The Solution:** Veta automatically breaks down your markdown documents into sections, tracks your learning progress for each section, and reminds you to review at the optimal time for long-term retention.

**Who is it for:**
- 🎓 Students learning new topics
- 👨‍💻 Developers memorizing syntax and APIs
- 📚 Anyone who keeps study notes in markdown and wants to review them effectively

## Features

- 📚 Import markdown files from GitHub repositories (public and private)
- 🧠 Smart repetition algorithm for effective learning
- 📖 Full document viewer with table of contents navigation
- 💻 Syntax highlighting for code blocks (supports multiple languages)
- 📊 Track your progress and streaks
- 🔄 Sync progress across devices via GitHub Gist
- 🌓 Dark and light theme support
- 📱 Native iOS app

## Architecture

- **SwiftUI** for the user interface
- **SwiftData** for local persistence
- **GitHub API** for fetching repositories and files
- **MarkdownUI** for rendering markdown content
- **Highlightr** for syntax highlighting in code blocks
- **KeychainAccess** for secure token storage

## Project Structure

```
veta/
├── Models/              # Data models (SwiftData)
├── Services/            # Business logic services
│   ├── GitHub/          # GitHub API integration
│   ├── Gist/            # Gist sync service
│   ├── Markdown/        # Markdown parsing
│   └── Storage/         # Local storage management
├── Core/                # Core algorithms (repetition engine)
├── Utilities/           # Helpers and utilities
│   ├── Extensions/      # Swift extensions
│   ├── CodeSyntaxHighlighter.swift
│   └── HTMLToMarkdownConverter.swift
├── Views/               # SwiftUI views
│   ├── Study/           # Study mode views
│   ├── Documents/       # Document browser
│   ├── Repositories/    # Repository management
│   ├── Statistics/      # Progress tracking
│   ├── Settings/        # App settings
│   └── Components/      # Reusable UI components
└── ViewModels/          # View models
```

## Getting Started

### Prerequisites

- Xcode 15.0+
- iOS 17.0+ / macOS 14.0+
- Swift 5.9+

### Installation

1. Clone the repository
2. Open `veta.xcodeproj` in Xcode
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
- ✅ GitHub API integration (public and private repos)
- ✅ Markdown parsing and rendering
- ✅ Syntax highlighting for code blocks
- ✅ Full document viewer with table of contents
- ✅ Anchor navigation with non-ASCII character support
- ✅ Basic repetition algorithm
- ✅ GitHub Gist synchronization
- ✅ Secure token storage with Keychain
- ✅ iOS UI (Study, Documents, Repositories, Statistics, Settings)
- ✅ Dark and light theme support

### TODO
- ⏳ GitHub OAuth authentication
- ⏳ Image caching and optimization
- ⏳ macOS version
- ⏳ Advanced spaced repetition (SM-2 algorithm)
- ⏳ Search and filtering
- ⏳ Export/import functionality
- ⏳ Markdown code block parsing improvements

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
