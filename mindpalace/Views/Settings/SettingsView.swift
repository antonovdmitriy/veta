import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]

    @State private var dailyGoal = Constants.Repetition.defaultDailyGoal
    @State private var showImages = true
    @State private var autoSync = true
    @State private var githubToken = ""
    @State private var showingTokenInput = false

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
                } header: {
                    Text("Preferences")
                }

                Section {
                    Button("Export Data") {
                        // TODO: Implement export
                    }

                    Button("Import Data") {
                        // TODO: Implement import
                    }
                } header: {
                    Text("Data")
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
            .sheet(isPresented: $showingTokenInput) {
                TokenInputView(token: $githubToken) {
                    saveSettings()
                    showingTokenInput = false
                }
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
            userSettings.githubToken = githubToken.isEmpty ? nil : githubToken
            try? modelContext.save()
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
