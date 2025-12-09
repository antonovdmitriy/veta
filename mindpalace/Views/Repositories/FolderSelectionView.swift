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

                ToolbarItem(placement: .principal) {
                    if !folderStructure.isEmpty {
                        Button {
                            loadFolderStructure()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.body)
                        }
                        .disabled(isLoading)
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

        // Use already synced files instead of fetching from API
        let syncedFiles = repository.files

        if syncedFiles.isEmpty {
            errorMessage = "No files synced yet. Please sync this repository first."
            isLoading = false
            return
        }

        // Build folder tree from synced files
        let filePaths = syncedFiles.map { GitHubContent(
            name: $0.fileName,
            path: $0.path,
            sha: $0.sha ?? "",
            size: 0,
            url: "",
            htmlUrl: "",
            gitUrl: "",
            downloadUrl: nil,
            type: .file
        )}

        let nodes = buildFolderTree(from: filePaths)

        folderStructure = nodes
        isLoading = false
    }

    private func buildFolderTree(from files: [GitHubContent]) -> [FolderNode] {

        // Collect all unique folder paths
        var folderPaths = Set<String>()
        var folderFileCounts: [String: Int] = [:]

        for file in files {
            let components = file.path.components(separatedBy: "/")

            // Build all parent folder paths
            var currentPath = ""
            for component in components.dropLast() {
                currentPath += (currentPath.isEmpty ? "" : "/") + component
                folderPaths.insert(currentPath)
            }

            // Count files in the immediate parent folder
            if components.count > 1 {
                let parentPath = components.dropLast().joined(separator: "/")
                folderFileCounts[parentPath, default: 0] += 1
            }
        }

        // Build nodes for all folders
        var allNodes: [String: FolderNode] = [:]
        for path in folderPaths {
            let components = path.components(separatedBy: "/")
            let name = components.last ?? path
            let isSelected = repository.shouldIncludePath(path)
            let isFavorite = repository.favoritePaths.contains { favPath in
                path == favPath || path.hasPrefix(favPath + "/")
            }
            let fileCount = folderFileCounts[path] ?? 0

            allNodes[path] = FolderNode(
                name: name,
                path: path,
                isSelected: isSelected,
                isFavorite: isFavorite,
                fileCount: fileCount,
                children: []
            )
        }

        // Build hierarchy: assign children to parents
        for (path, var node) in allNodes {
            let components = path.components(separatedBy: "/")

            // Find all direct children
            var children: [FolderNode] = []
            for (childPath, childNode) in allNodes {
                let childComponents = childPath.components(separatedBy: "/")

                // Check if this is a direct child (one level deeper)
                if childComponents.count == components.count + 1 {
                    let parentPath = childComponents.dropLast().joined(separator: "/")
                    if parentPath == path {
                        children.append(childNode)
                    }
                }
            }

            node.children = children.sorted { $0.name < $1.name }
            allNodes[path] = node
        }

        // Return only root level folders
        let rootNodes = allNodes.values.filter { node in
            !node.path.contains("/") || node.path.components(separatedBy: "/").count == 1
        }

        return rootNodes.sorted { $0.name < $1.name }
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
        var favorites: [String] = []

        collectPaths(from: folderStructure, included: &included, excluded: &excluded, favorites: &favorites)

        // Special case: if nothing is selected, set included to ["__NONE__"] marker
        if included.isEmpty && excluded.count > 0 {
            repository.includedPaths = ["__NONE__"]
            repository.excludedPaths = []
        } else {
            repository.includedPaths = included
            repository.excludedPaths = excluded
        }

        repository.favoritePaths = favorites

        do {
            try modelContext.save()
        } catch {
            print("❌ Error saving folder selection: \(error)")
        }
    }

    private func collectPaths(from nodes: [FolderNode], included: inout [String], excluded: inout [String], favorites: inout [String]) {
        for node in nodes {
            if node.isSelected {
                included.append(node.path)
            } else {
                excluded.append(node.path)
            }

            if node.isFavorite {
                favorites.append(node.path)
            }

            collectPaths(from: node.children, included: &included, excluded: &excluded, favorites: &favorites)
        }
    }
}

// MARK: - Folder Node

struct FolderNode: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    var isSelected: Bool
    var isFavorite: Bool
    var fileCount: Int
    var children: [FolderNode]

    init(name: String, path: String, isSelected: Bool, isFavorite: Bool = false, fileCount: Int, children: [FolderNode] = []) {
        self.name = name
        self.path = path
        self.isSelected = isSelected
        self.isFavorite = isFavorite
        self.fileCount = fileCount
        self.children = children
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    @Binding var node: FolderNode
    @State private var isExpanded: Bool = true
    let level: Int

    init(node: Binding<FolderNode>, level: Int = 0) {
        self._node = node
        self.level = level
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Main folder row
            HStack(spacing: 8) {
                // Indentation
                if level > 0 {
                    Spacer()
                        .frame(width: CGFloat(level * 20))
                }

                // Expand/collapse chevron for folders with children
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }

                Image(systemName: node.children.isEmpty ? "doc.text" : "folder.fill")
                    .foregroundStyle(node.isSelected ? .blue : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.subheadline)
                        .fontWeight(level == 0 ? .semibold : .regular)

                    if node.fileCount > 0 {
                        Text("\(node.fileCount) files")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Favorite star button
                Button {
                    node.isFavorite.toggle()
                } label: {
                    Image(systemName: node.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(node.isFavorite ? .yellow : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)

                Toggle("", isOn: $node.isSelected)
                    .labelsHidden()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())

            // Children (shown when expanded)
            if isExpanded && !node.children.isEmpty {
                ForEach(Array($node.children.enumerated()), id: \.offset) { index, $child in
                    FolderRow(
                        node: $child,
                        level: level + 1
                    )
                }
            }
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
