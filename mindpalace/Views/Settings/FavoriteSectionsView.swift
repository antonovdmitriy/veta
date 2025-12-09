import SwiftUI
import SwiftData

struct FavoriteSectionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<MarkdownSection> { $0.isFavoriteSection == true })
    private var favoriteSections: [MarkdownSection]

    @State private var showingClearAllConfirmation = false

    var body: some View {
        List {
            if favoriteSections.isEmpty {
                ContentUnavailableView(
                    "No Favorite Sections",
                    systemImage: "star",
                    description: Text("Sections you mark as favorite during study will appear here")
                )
            } else {
                ForEach(favoriteSections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(section.title)
                                .font(.headline)

                            Spacer()

                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }

                        if let fileName = section.file?.fileName {
                            Text(fileName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            unfavoriteSection(section)
                        } label: {
                            Label("Unfavorite", systemImage: "star.slash")
                        }
                        .tint(.orange)
                    }
                }
            }
        }
        .navigationTitle("Favorite Sections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !favoriteSections.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear All") {
                        showingClearAllConfirmation = true
                    }
                }
            }
        }
        .alert("Clear All Favorite Sections?", isPresented: $showingClearAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                clearAllFavorites()
            }
        } message: {
            Text("All sections will be unfavorited. They will still appear in study but with normal priority.")
        }
    }

    private func unfavoriteSection(_ section: MarkdownSection) {
        section.isFavoriteSection = false

        do {
            try modelContext.save()
        } catch {
            print("❌ Error unfavoriting section: \(error)")
        }
    }

    private func clearAllFavorites() {
        for section in favoriteSections {
            section.isFavoriteSection = false
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Error clearing favorite sections: \(error)")
        }
    }
}

#Preview {
    FavoriteSectionsView()
        .modelContainer(for: [MarkdownSection.self], inMemory: true)
}
