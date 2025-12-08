import SwiftUI
import SwiftData

struct RepositoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var repositories: [GitHubRepository]
    @State private var showingAddRepository = false
    @State private var isSyncing = false
    @State private var syncManager: SyncManager?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if repositories.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(repositories) { repository in
                            RepositoryRow(repository: repository)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteRepository(repository)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
            .navigationTitle("Repositories")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddRepository = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        syncAll()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .disabled(isSyncing)
                }
            }
            .sheet(isPresented: $showingAddRepository) {
                AddRepositoryView()
            }
            .alert("Sync Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .overlay {
                if isSyncing {
                    VStack {
                        ProgressView("Syncing repositories...")
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .shadow(radius: 4)
                    }
                }
            }
            .onAppear {
                if syncManager == nil {
                    syncManager = SyncManager(modelContext: modelContext)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Repositories")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add a GitHub repository to start learning")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingAddRepository = true
            } label: {
                Label("Add Repository", systemImage: "plus")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
    }

    private func deleteRepository(_ repository: GitHubRepository) {
        modelContext.delete(repository)
        try? modelContext.save()
    }

    private func syncAll() {
        guard let syncManager = syncManager else { return }

        isSyncing = true
        errorMessage = nil

        Task {
            do {
                try await syncManager.syncAllRepositories()
                await MainActor.run {
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }
}

struct RepositoryRow: View {
    let repository: GitHubRepository
    @State private var showingFolderSelection = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(repository.name)
                    .font(.headline)

                HStack {
                    Text(repository.owner)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    if let lastSync = repository.lastSync {
                        Text("Updated \(lastSync.shortRelativeString)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Label("\(repository.files.count) files", systemImage: "doc")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if !repository.includedPaths.isEmpty || !repository.excludedPaths.isEmpty {
                        Label("Filtered", systemImage: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    Spacer()

                    if repository.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Button {
                showingFolderSelection = true
            } label: {
                Image(systemName: "folder.badge.gearshape")
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingFolderSelection) {
            FolderSelectionView(repository: repository)
        }
    }
}

#Preview {
    RepositoriesView()
        .modelContainer(for: [GitHubRepository.self], inMemory: true)
}
