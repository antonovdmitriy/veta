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
    @State private var selectedTheme: AppTheme = .system
    @State private var baseFontSize: Double = 16.0
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

                    Picker("Theme", selection: $selectedTheme) {
                        Text("System").tag(AppTheme.system)
                        Text("Light").tag(AppTheme.light)
                        Text("Dark").tag(AppTheme.dark)
                    }

                    FontSizeSlider(fontSize: $baseFontSize) {
                        saveSettings()
                    }

                    NavigationLink {
                        RepetitionSettingsView()
                    } label: {
                        HStack {
                            Label("Algorithm Settings", systemImage: "slider.horizontal.3")
                            Spacer()
                        }
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

                    Link(destination: URL(string: "https://github.com/antonovdmitriy/veta")!) {
                        HStack {
                            Label("GitHub Repository", systemImage: "link")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "https://github.com/antonovdmitriy/veta/issues")!) {
                        HStack {
                            Label("Report Issue", systemImage: "exclamationmark.bubble")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
            selectedTheme = userSettings.theme
            baseFontSize = userSettings.baseFontSize
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
            userSettings.theme = selectedTheme
            userSettings.baseFontSize = baseFontSize
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

struct FontSizeSlider: View {
    @Binding var fontSize: Double
    let onSave: () -> Void

    @State private var localValue: Double

    init(fontSize: Binding<Double>, onSave: @escaping () -> Void) {
        self._fontSize = fontSize
        self.onSave = onSave
        self._localValue = State(initialValue: fontSize.wrappedValue)
    }

    var body: some View {
        HStack {
            Text("Font Size")
            Spacer()
            Slider(value: $localValue, in: 12...24, step: 1, onEditingChanged: { isEditing in
                if !isEditing {
                    fontSize = localValue
                    onSave()
                }
            })
            .frame(width: 150)
            Text("\(Int(localValue))pt")
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)
                .monospacedDigit()
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
                        .font(.system(.body, design: .monospaced))
                } header: {
                    Text("GitHub Personal Access Token")
                } footer: {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Increases API limits from 60 to 5,000 requests/hour", systemImage: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)

                        Label("Enables access to private repositories", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)

                        Divider()
                            .padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to generate:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("1. Visit github.com/settings/tokens")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("2. Click 'Generate new token (classic)'")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("3. Select 'repo' scope for full access")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
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
                    .fontWeight(.semibold)
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
