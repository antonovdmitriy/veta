import SwiftUI
import SwiftData

struct RepositoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var repositories: [GitHubRepository]
    @State private var showingAddRepository = false
    @State private var showingSuggestedRepositories = false
    @State private var isSyncing = false
    @State private var syncManager: SyncManager?
    @State private var errorMessage: String?
    @State private var syncProgress: Double = 0.0

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
                    Menu {
                        Button {
                            showingAddRepository = true
                        } label: {
                            Label("Add Repository", systemImage: "plus.circle")
                        }

                        Button {
                            showingSuggestedRepositories = true
                        } label: {
                            Label("Browse Examples", systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(isSyncing)
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
            .sheet(isPresented: $showingSuggestedRepositories) {
                SuggestedRepositoriesSheet(
                    onRepositoryAdded: {},
                    onRepositoryAddedWithSync: { repository in
                        syncRepository(repository)
                    }
                )
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
                if isSyncing, let syncManager = syncManager {
                    ZStack {
                        // Semi-transparent background to block interactions
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        // Progress card
                        VStack(spacing: 16) {
                            ProgressView(value: syncProgress, total: 1.0)
                                .progressViewStyle(.linear)
                                .frame(width: 200)
                                .tint(.blue)

                            VStack(spacing: 4) {
                                if syncManager.totalRepositories > 1 {
                                    Text("Syncing \(syncManager.currentRepositoryIndex)/\(syncManager.totalRepositories)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if !syncManager.currentRepositoryName.isEmpty {
                                        Text(syncManager.currentRepositoryName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                } else {
                                    Text("Syncing repository...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                Text("\(Int(syncProgress * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
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
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 120, height: 120)

                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 12) {
                Text("No Repositories")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Add a GitHub repository to start learning with Veta")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showingAddRepository = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Repository")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }

            Text("or")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                showingSuggestedRepositories = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                    Text("Browse Examples")
                }
                .font(.headline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteRepository(_ repository: GitHubRepository) {
        // Force load all attributes before deletion to avoid SwiftData faults
        _ = repository.includedPaths
        _ = repository.excludedPaths
        _ = repository.favoritePaths
        _ = repository.files

        modelContext.delete(repository)

        do {
            try modelContext.save()
        } catch {
            print("Error deleting repository: \(error)")
        }
    }

    private func syncRepository(_ repository: GitHubRepository) {
        guard let syncManager = syncManager else { return }

        isSyncing = true
        syncProgress = 0.0
        errorMessage = nil

        Task {
            // Update progress periodically
            let progressTask = Task {
                while !Task.isCancelled {
                    await MainActor.run {
                        syncProgress = syncManager.progress
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            do {
                try await syncManager.syncRepository(repository)
                progressTask.cancel()
                await MainActor.run {
                    syncProgress = 1.0
                    isSyncing = false
                }
            } catch {
                progressTask.cancel()
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }

    private func syncAll() {
        guard let syncManager = syncManager else { return }

        isSyncing = true
        syncProgress = 0.0
        errorMessage = nil

        Task {
            // Update progress periodically
            let progressTask = Task {
                while !Task.isCancelled {
                    await MainActor.run {
                        // Calculate overall progress across all repositories
                        if syncManager.totalRepositories > 0 {
                            let completedRepos = Double(syncManager.currentRepositoryIndex - 1)
                            let currentRepoProgress = syncManager.progress
                            syncProgress = (completedRepos + currentRepoProgress) / Double(syncManager.totalRepositories)
                        } else {
                            syncProgress = syncManager.progress
                        }
                    }
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }

            do {
                try await syncManager.syncAllRepositories()
                progressTask.cancel()
                await MainActor.run {
                    syncProgress = 1.0
                    isSyncing = false
                }
            } catch {
                progressTask.cancel()
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
