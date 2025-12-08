import SwiftUI
import SwiftData

struct FolderSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]

    let repository: GitHubRepository
    @State private var folderStructure: [FolderNode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView("Loading folder structure...")
                        .padding()
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    // Toolbar with actions
                    HStack {
                        Button("Select All") {
                            selectAll()
                        }
                        .buttonStyle(.bordered)

                        Button("Deselect All") {
                            deselectAll()
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Text("\(selectedCount) selected")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()

                    // Folder list
                    List {
                        ForEach($folderStructure) { $node in
                            FolderRow(node: $node)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle("Select Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePaths()
                        dismiss()
                    }
                    .disabled(isLoading)
                }
            }
            .onAppear {
                loadFolderStructure()
            }
        }
    }

    private var selectedCount: Int {
        countSelected(in: folderStructure)
    }

    private func countSelected(in nodes: [FolderNode]) -> Int {
        var count = 0
        for node in nodes {
            if node.isSelected {
                count += 1
            }
            count += countSelected(in: node.children)
        }
        return count
    }

    private func loadFolderStructure() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let service = GitHubService(
                    token: repository.accessToken ?? settings.first?.githubToken
                )

                // Get all markdown files
                let files = try await service.listMarkdownFiles(
                    owner: repository.owner,
                    repo: repository.name
                )

                // Build folder tree
                let nodes = buildFolderTree(from: files)

                await MainActor.run {
                    self.folderStructure = nodes
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load folders: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }

    private func buildFolderTree(from files: [GitHubContent]) -> [FolderNode] {
        var root: [String: FolderNode] = [:]

        for file in files {
            let components = file.path.components(separatedBy: "/")
            guard components.count > 1 else { continue } // Skip root files

            var currentLevel = root
            var currentPath = ""

            for (index, component) in components.dropLast().enumerated() {
                currentPath += (currentPath.isEmpty ? "" : "/") + component

                if currentLevel[component] == nil {
                    let isSelected = repository.shouldIncludePath(currentPath)
                    currentLevel[component] = FolderNode(
                        name: component,
                        path: currentPath,
                        isSelected: isSelected,
                        fileCount: 0
                    )
                }

                if index < components.count - 2 {
                    var node = currentLevel[component]!
                    currentLevel = extractChildren(&node)
                    currentLevel[component] = node
                }
            }

            // Increment file count
            let parentFolder = components.dropLast().last ?? ""
            if var node = currentLevel[parentFolder] {
                node.fileCount += 1
                currentLevel[parentFolder] = node
            }
        }

        return Array(root.values).sorted { $0.name < $1.name }
    }

    private func extractChildren(_ node: inout FolderNode) -> [String: FolderNode] {
        var children: [String: FolderNode] = [:]
        for child in node.children {
            children[child.name] = child
        }
        return children
    }

    private func selectAll() {
        folderStructure = folderStructure.map { node in
            var updated = node
            selectAllRecursive(&updated)
            return updated
        }
    }

    private func selectAllRecursive(_ node: inout FolderNode) {
        node.isSelected = true
        node.children = node.children.map { child in
            var updated = child
            selectAllRecursive(&updated)
            return updated
        }
    }

    private func deselectAll() {
        folderStructure = folderStructure.map { node in
            var updated = node
            deselectAllRecursive(&updated)
            return updated
        }
    }

    private func deselectAllRecursive(_ node: inout FolderNode) {
        node.isSelected = false
        node.children = node.children.map { child in
            var updated = child
            deselectAllRecursive(&updated)
            return updated
        }
    }

    private func savePaths() {
        var included: [String] = []
        var excluded: [String] = []

        collectPaths(from: folderStructure, included: &included, excluded: &excluded)

        repository.includedPaths = included
        repository.excludedPaths = excluded

        try? modelContext.save()
    }

    private func collectPaths(from nodes: [FolderNode], included: inout [String], excluded: inout [String]) {
        for node in nodes {
            if node.isSelected {
                included.append(node.path)
            } else {
                excluded.append(node.path)
            }
            collectPaths(from: node.children, included: &included, excluded: &excluded)
        }
    }
}

// MARK: - Folder Node

struct FolderNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var isSelected: Bool
    var fileCount: Int
    var children: [FolderNode] = []
}

// MARK: - Folder Row

struct FolderRow: View {
    @Binding var node: FolderNode

    var body: some View {
        HStack {
            Image(systemName: node.children.isEmpty ? "doc.text" : "folder")
                .foregroundStyle(node.isSelected ? .blue : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(node.name)
                    .font(.body)

                if node.fileCount > 0 {
                    Text("\(node.fileCount) markdown files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Toggle("", isOn: $node.isSelected)
                .labelsHidden()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            node.isSelected.toggle()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: GitHubRepository.self, configurations: config)

    let repo = GitHubRepository(
        name: "test-repo",
        owner: "testuser",
        url: "https://github.com/testuser/test-repo"
    )

    return FolderSelectionView(repository: repo)
        .modelContainer(container)
}
