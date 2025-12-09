import SwiftUI
import SwiftData

struct DocumentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var repositories: [GitHubRepository]
    @State private var searchText = ""
    @State private var selectedFile: MarkdownFile?
    @State private var isRefreshing = false

    private var allFiles: [MarkdownFile] {
        repositories.flatMap { $0.files }
    }

    private var filteredFiles: [MarkdownFile] {
        if searchText.isEmpty {
            return allFiles.sorted { $0.fileName < $1.fileName }
        }
        return allFiles.filter { file in
            file.fileName.localizedCaseInsensitiveContains(searchText) ||
            file.path.localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.fileName < $1.fileName }
    }

    private var groupedFiles: [(repository: GitHubRepository, files: [MarkdownFile])] {
        let grouped = Dictionary(grouping: filteredFiles) { file in
            file.repository
        }
        return grouped.compactMap { repo, files -> (GitHubRepository, [MarkdownFile])? in
            guard let repository = repo else { return nil }
            return (repository, files.sorted { $0.fileName < $1.fileName })
        }.sorted { $0.repository.name < $1.repository.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if groupedFiles.isEmpty {
                    ContentUnavailableView {
                        Label("No Documents", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Add repositories from the Repositories tab to see documents here.")
                    }
                } else {
                    ForEach(groupedFiles, id: \.repository.id) { repository, files in
                        Section {
                            ForEach(files) { file in
                                Button {
                                    selectedFile = file
                                } label: {
                                    DocumentRow(file: file)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(.blue)
                                Text(repository.name)
                                    .font(.headline)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search documents...")
            .navigationTitle("Documents")
            .refreshable {
                await refreshRepositories()
            }
            .sheet(item: $selectedFile) { file in
                FullDocumentView(file: file)
            }
        }
    }

    private func refreshRepositories() async {
        let syncManager = SyncManager(modelContext: modelContext)

        for repository in repositories {
            try? await syncManager.syncRepository(repository)
        }

        // Add haptic feedback
        await MainActor.run {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

// MARK: - Document Row

struct DocumentRow: View {
    let file: MarkdownFile

    private var sectionCount: Int {
        file.sections.count
    }

    private var fileIcon: String {
        if file.fileName.lowercased().contains("readme") {
            return "doc.text.fill"
        } else if file.path.contains("/") {
            return "doc"
        } else {
            return "doc.plaintext"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.fileName)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(sectionCount) sections", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(file.lastUpdated, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    DocumentsView()
        .modelContainer(for: [
            GitHubRepository.self,
            MarkdownFile.self,
            MarkdownSection.self
        ], inMemory: true)
}
