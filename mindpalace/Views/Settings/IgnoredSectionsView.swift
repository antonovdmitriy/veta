import SwiftUI
import SwiftData

struct IgnoredSectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MarkdownSection> { $0.isIgnored == true })
    private var ignoredSections: [MarkdownSection]

    @State private var showingClearAllConfirmation = false

    var body: some View {
        List {
            if ignoredSections.isEmpty {
                ContentUnavailableView(
                    "No Ignored Sections",
                    systemImage: "checkmark.circle",
                    description: Text("Sections you ignore during study will appear here")
                )
            } else {
                ForEach(ignoredSections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(.headline)

                        if let fileName = section.file?.fileName {
                            Text(fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            unignoreSection(section)
                        } label: {
                            Label("Unignore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .navigationTitle("Ignored Sections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !ignoredSections.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear All") {
                        showingClearAllConfirmation = true
                    }
                }
            }
        }
        .alert("Clear All Ignored Sections?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllIgnored()
            }
        } message: {
            Text("All ignored sections will be unignored and may appear again in your study sessions.")
        }
    }

    private func unignoreSection(_ section: MarkdownSection) {
        section.isIgnored = false

        do {
            try modelContext.save()
        } catch {
            print("❌ Error unignoring section: \(error)")
        }
    }

    private func clearAllIgnored() {
        for section in ignoredSections {
            section.isIgnored = false
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Error clearing ignored sections: \(error)")
        }
    }
}

#Preview {
    IgnoredSectionsView()
        .modelContainer(for: [MarkdownSection.self], inMemory: true)
}
