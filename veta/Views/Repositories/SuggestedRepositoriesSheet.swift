import SwiftUI
import SwiftData

struct SuggestedRepositoriesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingRepositories: [GitHubRepository]

    let onRepositoryAdded: () -> Void

    @State private var addingRepository: Constants.SuggestedRepository?
    @State private var isAdding = false
    @State private var addedRepository: GitHubRepository?
    @State private var showSyncConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Browse popular learning repositories to get started")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                ForEach(Constants.suggestedRepositories) { repo in
                    SuggestedRepositoryRow(
                        repository: repo,
                        isAdding: isAdding && addingRepository?.id == repo.id,
                        isAlreadyAdded: isRepositoryAlreadyAdded(repo.url),
                        onAdd: {
                            addRepository(repo)
                        }
                    )
                }
            }
            .navigationTitle("Suggested Repositories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Repository Added", isPresented: $showSyncConfirmation) {
                Button("Sync Now") {
                    syncAddedRepository()
                }
                Button("Later", role: .cancel) {
                    addedRepository = nil
                }
            } message: {
                Text("Would you like to sync this repository now to download its content?")
            }
        }
    }

    private func isRepositoryAlreadyAdded(_ url: String) -> Bool {
        existingRepositories.contains { $0.url == url }
    }

    private func addRepository(_ suggested: Constants.SuggestedRepository) {
        // Check if already added
        if isRepositoryAlreadyAdded(suggested.url) {
            return
        }

        isAdding = true
        addingRepository = suggested

        Task {
            // Extract owner and repo name from URL
            guard let components = suggested.url.githubRepoComponents else {
                isAdding = false
                return
            }

            let repository = GitHubRepository(
                name: components.name,
                owner: components.owner,
                url: suggested.url,
                isPrivate: false,
                defaultBranch: "main"
            )

            modelContext.insert(repository)

            // Just get repository info (don't create file entries yet - sync will do that)
            let service = GitHubService()

            do {
                // Get repository info
                let repoInfo = try await service.getRepository(owner: components.owner, name: components.name)
                repository.defaultBranch = repoInfo.defaultBranch

                try modelContext.save()

                await MainActor.run {
                    isAdding = false
                    addedRepository = repository
                    showSyncConfirmation = true
                    onRepositoryAdded()
                }
            } catch {
                print("Error adding repository: \(error)")
                isAdding = false
            }
        }
    }

    private func syncAddedRepository() {
        guard let repository = addedRepository else { return }

        Task {
            let syncManager = SyncManager(modelContext: modelContext)
            do {
                try await syncManager.syncRepository(repository)
                await MainActor.run {
                    addedRepository = nil
                    dismiss()
                }
            } catch {
                print("Error syncing repository: \(error)")
                await MainActor.run {
                    addedRepository = nil
                }
            }
        }
    }
}

struct SuggestedRepositoryRow: View {
    let repository: Constants.SuggestedRepository
    let isAdding: Bool
    let isAlreadyAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(repository.icon)
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 4) {
                Text(repository.name)
                    .font(.headline)

                Text(repository.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(repository.category)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }

            Spacer()

            if isAlreadyAdded {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
            } else if isAdding {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button {
                    onAdd()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SuggestedRepositoriesSheet(onRepositoryAdded: {})
        .modelContainer(for: [
            GitHubRepository.self,
            MarkdownFile.self,
            MarkdownSection.self,
            RepetitionRecord.self,
            UserSettings.self
        ], inMemory: true)
}
