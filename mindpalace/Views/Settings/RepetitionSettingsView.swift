import SwiftUI
import SwiftData

struct RepetitionSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    @State private var favoriteBoostMultiplier: Double = 1.5
    @State private var favoriteFolderBoostMultiplier: Double = 1.3
    @State private var favoriteSectionWeight: Double = 0.6
    @State private var minimumContentLength: Double = 50
    @State private var linkRatioThreshold: Double = 0.7
    @State private var topSectionsShuffleCount: Double = 50
    @State private var cacheDurationSeconds: Double = 30
    @State private var showingResetConfirmation = false

    private var currentSettings: UserSettings? {
        settings.first
    }

    var body: some View {
        Form {
            Section {
                Text("Priority determines urgency of review. Higher priority sections appear sooner. New sections start at priority 1000, with +1 per day since last review.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Base Priority Calculation")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Sections Boost: ×\(String(format: "%.1f", favoriteBoostMultiplier))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $favoriteBoostMultiplier, in: 1.0...3.0, step: 0.1)
                        .tint(.blue)
                    Text("Sections marked with star icon")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Folders Boost: ×\(String(format: "%.1f", favoriteFolderBoostMultiplier))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $favoriteFolderBoostMultiplier, in: 1.0...2.0, step: 0.1)
                        .tint(.blue)
                    Text("Sections from folders marked with star")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Priority Multipliers")
            } footer: {
                Text("Multipliers are applied to base priority to make favorites appear more frequently.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Favorite Sections Weight: \(Int(favoriteSectionWeight * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $favoriteSectionWeight, in: 0.3...0.9, step: 0.05)
                        .tint(.orange)
                    HStack {
                        Text("Favorites: \(Int(favoriteSectionWeight * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("Regular: \(Int((1 - favoriteSectionWeight) * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Interleaving Strategy")
            } footer: {
                Text("After sorting by priority, sections are randomly selected with these probabilities. This ensures favorites appear more often but not exclusively.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Top Sections Shuffle: \(Int(topSectionsShuffleCount))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $topSectionsShuffleCount, in: 10...100, step: 10)
                        .tint(.green)
                    Text("Number of top-priority sections to shuffle for variety")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Cache Duration: \(Int(cacheDurationSeconds))s")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $cacheDurationSeconds, in: 10...120, step: 10)
                        .tint(.green)
                    Text("Pre-computed section queue validity period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Performance & Variety")
            } footer: {
                Text("Cache improves performance. Shuffling top sections adds variety while maintaining priority order.")
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Minimum Content Length: \(Int(minimumContentLength)) chars")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $minimumContentLength, in: 20...200, step: 10)
                        .tint(.purple)
                    Text("Sections shorter than this are skipped")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Link Ratio Threshold: \(Int(linkRatioThreshold * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $linkRatioThreshold, in: 0.5...0.9, step: 0.05)
                        .tint(.purple)
                    Text("Sections with >\(Int(linkRatioThreshold * 100))% list items are skipped (likely TOC)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Content Filtering")
            } footer: {
                Text("These filters automatically skip sections that are not suitable for study (like tables of contents).")
            }
        }
        .navigationTitle("Algorithm Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Reset") {
                    showingResetConfirmation = true
                }
                .foregroundStyle(.red)
            }
        }
        .alert("Reset to Default Settings?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetToDefaults()
            }
        } message: {
            Text("All algorithm settings will be reset to their default values. This action cannot be undone.")
        }
        .onAppear {
            loadSettings()
        }
        .onChange(of: favoriteBoostMultiplier) { _, _ in saveSettings() }
        .onChange(of: favoriteFolderBoostMultiplier) { _, _ in saveSettings() }
        .onChange(of: favoriteSectionWeight) { _, _ in saveSettings() }
        .onChange(of: minimumContentLength) { _, _ in saveSettings() }
        .onChange(of: linkRatioThreshold) { _, _ in saveSettings() }
        .onChange(of: topSectionsShuffleCount) { _, _ in saveSettings() }
        .onChange(of: cacheDurationSeconds) { _, _ in saveSettings() }
    }

    private func loadSettings() {
        if let userSettings = currentSettings {
            favoriteBoostMultiplier = userSettings.favoriteBoostMultiplier
            favoriteFolderBoostMultiplier = userSettings.favoriteFolderBoostMultiplier
            favoriteSectionWeight = userSettings.favoriteSectionWeight
            minimumContentLength = Double(userSettings.minimumContentLength)
            linkRatioThreshold = userSettings.linkRatioThreshold
            topSectionsShuffleCount = Double(userSettings.topSectionsShuffleCount)
            cacheDurationSeconds = Double(userSettings.cacheDurationSeconds)
        }
    }

    private func saveSettings() {
        if let userSettings = currentSettings {
            userSettings.favoriteBoostMultiplier = favoriteBoostMultiplier
            userSettings.favoriteFolderBoostMultiplier = favoriteFolderBoostMultiplier
            userSettings.favoriteSectionWeight = favoriteSectionWeight
            userSettings.minimumContentLength = Int(minimumContentLength)
            userSettings.linkRatioThreshold = linkRatioThreshold
            userSettings.topSectionsShuffleCount = Int(topSectionsShuffleCount)
            userSettings.cacheDurationSeconds = Int(cacheDurationSeconds)
            try? modelContext.save()
        }
    }

    private func resetToDefaults() {
        withAnimation {
            favoriteBoostMultiplier = 1.5
            favoriteFolderBoostMultiplier = 1.3
            favoriteSectionWeight = 0.6
            minimumContentLength = 50
            linkRatioThreshold = 0.7
            topSectionsShuffleCount = 50
            cacheDurationSeconds = 30
        }
        saveSettings()
    }
}

// MARK: - Info Row Component

struct InfoRow: View {
    let title: String
    let value: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        RepetitionSettingsView()
    }
}
