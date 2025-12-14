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
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.blue)
                        Text("Loading folder structure...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: .infinity)
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
                    VStack(spacing: 0) {
                        // Compact toolbar
                        HStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Button {
                                    selectAll()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle")
                                            .font(.caption)
                                        Text("Select All")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)

                                Button {
                                    deselectAll()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "circle")
                                            .font(.caption)
                                        Text("Clear")
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.red.opacity(0.1))
                                    .foregroundStyle(.red)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("\(selectedCount) selected")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .padding()
                        .background(Color(.systemBackground))

                        Divider()

                        // Help text
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select folders and files to include in your study sessions. Deselecting a folder automatically deselects all nested items.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 16) {
                                Label("Folder", systemImage: "folder.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Label("File", systemImage: "doc.text.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Label("Favorite (higher priority)", systemImage: "star.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                        // Folder list
                        List {
                            ForEach($folderStructure) { $node in
                                FolderRow(node: $node)
                            }
                        }
                        .listStyle(.inset)
                    }
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
                isFile: false,
                isSelected: isSelected,
                isFavorite: isFavorite,
                fileCount: fileCount,
                children: []
            )
        }

        // Add file nodes
        for file in files {
            let isSelected = repository.shouldIncludePath(file.path)
            let isFavorite = repository.favoritePaths.contains(file.path)

            allNodes[file.path] = FolderNode(
                name: file.name,
                path: file.path,
                isFile: true,
                isSelected: isSelected,
                isFavorite: isFavorite,
                fileCount: 0,
                children: []
            )
        }

        // Sort all paths by depth (deepest first) to build tree bottom-up
        let sortedPaths = allNodes.keys.sorted { path1, path2 in
            let depth1 = path1.components(separatedBy: "/").count
            let depth2 = path2.components(separatedBy: "/").count
            return depth1 > depth2  // Deeper paths first
        }

        // Build hierarchy from deepest to shallowest
        for path in sortedPaths {
            let components = path.components(separatedBy: "/")

            // Skip root level items (they have no parent)
            if components.count == 1 {
                continue
            }

            // Find parent path
            let parentPath = components.dropLast().joined(separator: "/")

            // Add this node to parent's children
            if var parentNode = allNodes[parentPath], let childNode = allNodes[path] {
                parentNode.children.append(childNode)

                // Sort children: folders first, then files, alphabetically within each group
                parentNode.children.sort { a, b in
                    if a.isFile != b.isFile {
                        return !a.isFile // folders before files
                    }
                    return a.name < b.name
                }

                allNodes[parentPath] = parentNode
            }
        }

        // Return only root level items (folders and files)
        let rootNodes = allNodes.values.filter { node in
            !node.path.contains("/") || node.path.components(separatedBy: "/").count == 1
        }

        return rootNodes.sorted { a, b in
            if a.isFile != b.isFile {
                return !a.isFile // folders before files
            }
            return a.name < b.name
        }
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
    let isFile: Bool
    var isSelected: Bool
    var isFavorite: Bool
    var fileCount: Int
    var children: [FolderNode]

    init(name: String, path: String, isFile: Bool = false, isSelected: Bool, isFavorite: Bool = false, fileCount: Int = 0, children: [FolderNode] = []) {
        self.name = name
        self.path = path
        self.isFile = isFile
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
                if !node.isFile && !node.children.isEmpty {
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

                Image(systemName: node.isFile ? "doc.text.fill" : "folder.fill")
                    .foregroundStyle(node.isSelected ? .blue : .secondary)
                    .font(.body)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.name)
                        .font(.subheadline)
                        .fontWeight(level == 0 && !node.isFile ? .semibold : .regular)

                    if !node.isFile {
                        if node.fileCount > 0 {
                            Text("\(node.fileCount) markdown \(node.fileCount == 1 ? "file" : "files")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else if node.children.isEmpty {
                            Text("empty folder")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }

                Spacer()

                // Favorite star button
                Button {
                    node.isFavorite.toggle()
                } label: {
                    Image(systemName: node.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(node.isFavorite ? .orange : .secondary)
                        .font(.body)
                }
                .buttonStyle(.plain)

                Toggle("", isOn: Binding(
                    get: { node.isSelected },
                    set: { newValue in
                        node.isSelected = newValue
                        // If deselecting parent, deselect all children
                        if !newValue {
                            deselectChildren(&node)
                        }
                        // If selecting parent and it has children, select them too
                        else if !node.children.isEmpty {
                            selectChildren(&node)
                        }
                    }
                ))
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

    private func selectChildren(_ node: inout FolderNode) {
        node.children = node.children.map { child in
            var updated = child
            updated.isSelected = true
            selectChildren(&updated)
            return updated
        }
    }

    private func deselectChildren(_ node: inout FolderNode) {
        node.children = node.children.map { child in
            var updated = child
            updated.isSelected = false
            deselectChildren(&updated)
            return updated
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
