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
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: name and settings button
            HStack(alignment: .center) {
                Text(repository.name)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Button {
                    showingFolderSelection = true
                } label: {
                    Image(systemName: "folder.badge.gearshape")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }

            // Owner link
            Button {
                if let url = URL(string: repository.url) {
                    openURL(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(repository.owner)
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }
            .buttonStyle(.borderless)

            // Metadata row
            HStack(spacing: 12) {
                Label("\(repository.files.count) files", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !repository.includedPaths.isEmpty || !repository.excludedPaths.isEmpty {
                    Label("Filtered", systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if repository.isPrivate {
                    Label("Private", systemImage: "lock.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Last sync
            if let lastSync = repository.lastSync {
                Text("Updated \(lastSync.shortRelativeString)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showingFolderSelection) {
            FolderSelectionView(repository: repository)
        }
    }
}

#Preview {
    RepositoriesView()
        .modelContainer(for: [GitHubRepository.self], inMemory: true)
}
