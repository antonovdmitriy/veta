import SwiftUI

struct RepetitionSettingsView: View {
    var body: some View {
        Form {
            Section {
                InfoRow(
                    title: "New Sections Priority",
                    value: "1000.0",
                    description: "Base priority for sections never reviewed"
                )

                InfoRow(
                    title: "Days Since Review",
                    value: "1.0 per day",
                    description: "Priority increases by 1 for each day since last review"
                )
            } header: {
                Text("Base Priority Calculation")
            } footer: {
                Text("Priority determines urgency of review. Higher priority sections appear sooner.")
            }

            Section {
                InfoRow(
                    title: "Favorite Sections Boost",
                    value: "×1.5 (50%)",
                    description: "Sections marked with star icon"
                )

                InfoRow(
                    title: "Favorite Folders Boost",
                    value: "×1.3 (30%)",
                    description: "Sections from folders marked with star"
                )
            } header: {
                Text("Priority Multipliers")
            } footer: {
                Text("Multipliers are applied to base priority to make favorites appear more frequently.")
            }

            Section {
                InfoRow(
                    title: "Favorite Sections Weight",
                    value: "60%",
                    description: "Probability of showing a favorite section"
                )

                InfoRow(
                    title: "Regular Sections Weight",
                    value: "40%",
                    description: "Probability of showing a regular section"
                )
            } header: {
                Text("Interleaving Strategy")
            } footer: {
                Text("After sorting by priority, sections are randomly selected with these probabilities. This ensures favorites appear more often but not exclusively.")
            }

            Section {
                InfoRow(
                    title: "Cache Duration",
                    value: "30 seconds",
                    description: "Pre-computed section queue validity period"
                )

                InfoRow(
                    title: "Top Sections Shuffle",
                    value: "50 sections",
                    description: "Number of top-priority sections to shuffle for variety"
                )
            } header: {
                Text("Performance & Variety")
            } footer: {
                Text("Cache improves performance. Shuffling top sections adds variety while maintaining priority order.")
            }

            Section {
                InfoRow(
                    title: "Minimum Content Length",
                    value: "50 characters",
                    description: "Sections shorter than this are skipped"
                )

                InfoRow(
                    title: "Link Ratio Threshold",
                    value: "70%",
                    description: "Sections with >70% list items are skipped (likely TOC)"
                )
            } header: {
                Text("Content Filtering")
            } footer: {
                Text("These filters automatically skip sections that are not suitable for study (like tables of contents).")
            }
        }
        .navigationTitle("Repetition Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let title: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        RepetitionSettingsView()
    }
}
