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
                await gitHubService.setToken(token)
            }

            // Get repository info to find default branch
            progress = 0.1
            let repoInfo = try await gitHubService.getRepository(
                owner: repository.owner,
                name: repository.name
            )
            let defaultBranch = repoInfo.defaultBranch

            // Fetch all markdown files
            progress = 0.2
            let markdownFiles = try await gitHubService.listMarkdownFiles(
                owner: repository.owner,
                repo: repository.name
            )

            print("Found \(markdownFiles.count) markdown files in \(repository.fullName)")

            // Filter files based on repository settings
            let filteredFiles = markdownFiles.filter { file in
                repository.shouldIncludePath(file.path)
            }

            print("Filtered to \(filteredFiles.count) files based on path settings")

            // Process each file
            let totalFiles = filteredFiles.count
            for (index, gitHubFile) in filteredFiles.enumerated() {
                try await processFile(gitHubFile, repository: repository, branch: defaultBranch)
                progress = 0.2 + (0.7 * Double(index + 1) / Double(totalFiles))
            }

            // Update last sync date
            await MainActor.run {
                repository.lastSync = Date()
                try? modelContext.save()
            }

            progress = 1.0
            print("Successfully synced \(repository.fullName)")

        } catch {
            lastError = error
            print("Error syncing repository: \(error)")
            throw error
        }
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

            print("Processed \(gitHubFile.name): \(parsedSections.count) sections")
        }
    }
}
