import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @Query(filter: #Predicate<MarkdownSection> { $0.isIgnored == true })
    private var ignoredSections: [MarkdownSection]
    @Query(filter: #Predicate<MarkdownSection> { $0.isFavoriteSection == true })
    private var favoriteSections: [MarkdownSection]

    @State private var dailyGoal = Constants.Repetition.defaultDailyGoal
    @State private var showImages = true
    @State private var autoSync = true
    @State private var selectedTheme: AppTheme = .system
    @State private var githubToken = ""
    @State private var showingTokenInput = false
    @State private var showingResetConfirmation = false

    private var ignoredSectionsCount: Int {
        ignoredSections.count
    }

    private var favoriteSectionsCount: Int {
        favoriteSections.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Status")
                        Spacer()
                        if currentSettings?.isAuthenticated == true {
                            Label("Connected", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Not connected", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    if currentSettings?.isAuthenticated == true {
                        Button("Update Token") {
                            showingTokenInput = true
                        }

                        Button("Disconnect", role: .destructive) {
                            githubToken = ""
                            saveSettings()
                        }
                    } else {
                        Button("Add GitHub Token") {
                            showingTokenInput = true
                        }
                    }
                } header: {
                    Text("GitHub Authentication")
                } footer: {
                    Text("Add a Personal Access Token to increase API limits and access private repositories. Generate at github.com/settings/tokens")
                }

                Section {
                    Stepper("Daily Goal: \(dailyGoal)", value: $dailyGoal, in: 1...100)
                    Toggle("Show Images", isOn: $showImages)
                    Toggle("Auto Sync", isOn: $autoSync)

                    Picker("Theme", selection: $selectedTheme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }

                    NavigationLink {
                        RepetitionSettingsView()
                    } label: {
                        Text("Repetition Algorithm")
                    }
                } header: {
                    Text("Preferences")
                }

                Section {
                    NavigationLink {
                        FavoriteSectionsView()
                    } label: {
                        HStack {
                            Text("Favorite Sections")
                            Spacer()
                            Text("\(favoriteSectionsCount)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    NavigationLink {
                        IgnoredSectionsView()
                    } label: {
                        HStack {
                            Text("Ignored Sections")
                            Spacer()
                            Text("\(ignoredSectionsCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Learning Data")
                }

                Section {
                    Button("Reset All Progress", role: .destructive) {
                        showingResetConfirmation = true
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Reset all progress will delete all repetition records. This action cannot be undone.")
                }

                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link("GitHub Repository", destination: URL(string: "https://github.com")!)
                    Link("Report Issue", destination: URL(string: "https://github.com")!)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadSettings()
            }
            .onChange(of: dailyGoal) { oldValue, newValue in
                saveSettings()
            }
            .onChange(of: showImages) { oldValue, newValue in
                saveSettings()
            }
            .onChange(of: autoSync) { oldValue, newValue in
                saveSettings()
            }
            .onChange(of: selectedTheme) { oldValue, newValue in
                saveSettings()
            }
            .sheet(isPresented: $showingTokenInput) {
                TokenInputView(token: $githubToken) {
                    saveSettings()
                    showingTokenInput = false
                }
            }
            .alert("Reset All Progress?", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetAllProgress()
                }
            } message: {
                Text("This will permanently delete all your repetition progress. You will start fresh with all sections. This action cannot be undone.")
            }
        }
    }

    private var currentSettings: UserSettings? {
        settings.first
    }

    private func loadSettings() {
        if let userSettings = currentSettings {
            dailyGoal = userSettings.dailyGoal
            showImages = userSettings.showImages
            autoSync = userSettings.autoSync
            selectedTheme = userSettings.theme
            githubToken = userSettings.githubToken ?? ""
        } else {
            // Create default settings
            let defaultSettings = UserSettings()
            modelContext.insert(defaultSettings)
            try? modelContext.save()
        }
    }

    private func saveSettings() {
        if let userSettings = currentSettings {
            userSettings.dailyGoal = dailyGoal
            userSettings.showImages = showImages
            userSettings.autoSync = autoSync
            userSettings.theme = selectedTheme
            userSettings.githubToken = githubToken.isEmpty ? nil : githubToken
            try? modelContext.save()
        }
    }

    private func resetAllProgress() {
        let descriptor = FetchDescriptor<RepetitionRecord>()

        do {
            let allRecords = try modelContext.fetch(descriptor)

            for record in allRecords {
                modelContext.delete(record)
            }

            try modelContext.save()
        } catch {
            print("❌ Error resetting progress: \(error)")
        }
    }
}

struct TokenInputView: View {
    @Binding var token: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("GitHub Personal Access Token")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("This token will be used for all repositories to increase API limits and access private repos.")
                        Text("Generate at: github.com/settings/tokens")
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("GitHub Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                    .disabled(token.isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [UserSettings.self], inMemory: true)
}
