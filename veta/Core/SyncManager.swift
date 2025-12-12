import Foundation
import SwiftData

@Observable
class SyncManager {
    private let modelContext: ModelContext
    private let gitHubService: GitHubService
    private let markdownParser: MarkdownParser

    var isSyncing = false
    var lastError: Error?
    var progress: Double = 0.0

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Get global token from settings
        let descriptor = FetchDescriptor<UserSettings>()
        let settings = try? modelContext.fetch(descriptor).first
        let token = settings?.githubToken

        self.gitHubService = GitHubService(token: token)
        self.markdownParser = MarkdownParser()
    }

    /// Syncs a specific repository
    func syncRepository(_ repository: GitHubRepository) async throws {
        isSyncing = true
        progress = 0.0
        lastError = nil

        defer {
            isSyncing = false
        }

        do {
            // Update token if needed
            if let token = repository.accessToken {
                gitHubService.setToken(token)
            }

            // Get repository info to find default branch
            progress = 0.1
            let repoInfo = try await gitHubService.getRepository(
                owner: repository.owner,
                name: repository.name
            )
            let defaultBranch = repoInfo.defaultBranch

            // Check if this is first sync (no existing files)
            let isFirstSync = repository.files.isEmpty

            if isFirstSync {
                // First sync: Download entire archive (1 request!)
                print("📦 First sync - downloading archive for \(repository.fullName)")
                try await syncViaArchive(repository: repository, branch: defaultBranch)
            } else {
                // Subsequent sync: Use Trees API + SHA checking
                print("🔄 Incremental sync for \(repository.fullName)")
                try await syncIncremental(repository: repository, branch: defaultBranch)
            }

            // Update last sync date
            await MainActor.run {
                repository.lastSync = Date()
                try? modelContext.save()
            }

            progress = 1.0

        } catch {
            lastError = error
            print("❌ Error syncing \(repository.fullName): \(error)")
            throw error
        }
    }

    // MARK: - Sync Methods

    /// Syncs repository by downloading archive (for first sync)
    private func syncViaArchive(repository: GitHubRepository, branch: String) async throws {
        progress = 0.2

        // Download archive
        let archiveData = try await gitHubService.downloadArchive(
            owner: repository.owner,
            repo: repository.name,
            ref: branch
        )

        progress = 0.4

        // Extract archive
        let extractedFiles = try AssetManager.shared.extractArchive(
            data: archiveData,
            owner: repository.owner,
            repo: repository.name
        )

        progress = 0.5

        // Categorize files
        let categorized = AssetManager.shared.categorizeFiles(extractedFiles)
        let markdownFiles = categorized.markdown

        // Filter based on repository settings
        let repoDir = AssetManager.shared.repositoryDirectory(owner: repository.owner, repo: repository.name)
        let filteredFiles = markdownFiles.filter { fileURL in
            let relativePath = fileURL.path.replacingOccurrences(of: repoDir.path + "/", with: "")
            return repository.shouldIncludePath(relativePath)
        }

        // Process each markdown file
        let totalFiles = filteredFiles.count
        for (index, fileURL) in filteredFiles.enumerated() {
            try await processLocalFile(fileURL, repository: repository, repoDir: repoDir)
            progress = 0.5 + (0.5 * Double(index + 1) / Double(totalFiles))
        }

        print("✅ Archive sync complete: \(totalFiles) markdown files, \(categorized.assets.count) assets")
    }

    /// Syncs repository incrementally (for subsequent syncs)
    private func syncIncremental(repository: GitHubRepository, branch: String) async throws {
        progress = 0.2

        // Fetch all markdown files using Trees API
        let markdownFiles = try await gitHubService.listMarkdownFiles(
            owner: repository.owner,
            repo: repository.name,
            branch: branch
        )

        // Filter files based on repository settings
        let filteredFiles = markdownFiles.filter { file in
            repository.shouldIncludePath(file.path)
        }

        // Process only changed files (compare SHA)
        let totalFiles = filteredFiles.count
        var processedCount = 0

        for (index, gitHubFile) in filteredFiles.enumerated() {
            // Check if file needs update
            let existingFile = repository.files.first { $0.path == gitHubFile.path }

            if existingFile == nil || existingFile?.sha != gitHubFile.sha {
                // File is new or changed - download and process
                try await processFile(gitHubFile, repository: repository, branch: branch)
                processedCount += 1
            }

            progress = 0.2 + (0.8 * Double(index + 1) / Double(totalFiles))
        }

        print("✅ Incremental sync complete: \(processedCount)/\(totalFiles) files updated")
    }

    /// Syncs all repositories
    func syncAllRepositories() async throws {
        let descriptor = FetchDescriptor<GitHubRepository>()
        guard let repositories = try? modelContext.fetch(descriptor) else {
            return
        }

        for repository in repositories {
            try await syncRepository(repository)
        }
    }

    // MARK: - Private Methods

    /// Process a file that's already been extracted locally (from archive)
    private func processLocalFile(_ fileURL: URL, repository: GitHubRepository, repoDir: URL) async throws {
        // Read file content
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let relativePath = fileURL.path.replacingOccurrences(of: repoDir.path + "/", with: "")

        await MainActor.run {
            // Check if file already exists
            let existingFile = repository.files.first { $0.path == relativePath }

            let file: MarkdownFile
            if let existing = existingFile {
                // Update existing file
                file = existing
                file.content = content
                file.lastUpdated = Date()
                // SHA will be updated later if needed

                // Remove old sections (will be recreated)
                file.sections.forEach { modelContext.delete($0) }
                file.sections.removeAll()
            } else {
                // Create new file
                file = MarkdownFile(
                    path: relativePath,
                    fileName: fileURL.lastPathComponent,
                    content: content,
                    sha: "", // Will be updated later if needed
                    repository: repository
                )
                modelContext.insert(file)
            }

            // Parse markdown into sections
            let parsedSections = markdownParser.parse(content: content)

            // Create MarkdownSection objects
            for parsed in parsedSections {
                let section = MarkdownSection(
                    title: parsed.title,
                    content: parsed.content,
                    level: parsed.level,
                    lineStart: parsed.lineStart,
                    lineEnd: parsed.lineEnd,
                    orderIndex: parsed.orderIndex,
                    file: file
                )
                modelContext.insert(section)
            }

            try? modelContext.save()
        }
    }

    private func processFile(_ gitHubFile: GitHubContent, repository: GitHubRepository, branch: String) async throws {
        // Download file content
        let content = try await gitHubService.downloadFileContent(
            owner: repository.owner,
            repo: repository.name,
            path: gitHubFile.path,
            ref: branch
        )

        await MainActor.run {
            // Check if file already exists
            let existingFile = repository.files.first { $0.path == gitHubFile.path }

            let file: MarkdownFile
            if let existing = existingFile {
                // Update existing file
                file = existing
                file.content = content
                file.lastUpdated = Date()
                file.sha = gitHubFile.sha

                // Remove old sections (will be recreated)
                file.sections.forEach { modelContext.delete($0) }
                file.sections.removeAll()
            } else {
                // Create new file
                file = MarkdownFile(
                    path: gitHubFile.path,
                    fileName: gitHubFile.name,
                    content: content,
                    sha: gitHubFile.sha,
                    repository: repository
                )
                modelContext.insert(file)
            }

            // Parse markdown into sections
            let parsedSections = markdownParser.parse(content: content)

            // Create MarkdownSection objects
            for parsed in parsedSections {
                let section = MarkdownSection(
                    title: parsed.title,
                    content: parsed.content,
                    level: parsed.level,
                    lineStart: parsed.lineStart,
                    lineEnd: parsed.lineEnd,
                    orderIndex: parsed.orderIndex,
                    file: file
                )
                modelContext.insert(section)
            }

            try? modelContext.save()
        }
    }
}
