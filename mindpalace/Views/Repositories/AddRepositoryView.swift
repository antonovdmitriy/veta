import SwiftUI
import SwiftData

struct AddRepositoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var settings: [UserSettings]

    @State private var repositoryURL = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Repository URL", text: $repositoryURL)
                        .textContentType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } header: {
                    Text("Repository")
                } footer: {
                    Text("Enter the full GitHub repository URL (e.g., https://github.com/owner/repo)")
                }

                if settings.first?.githubToken == nil {
                    Section {
                        Text("⚠️ No GitHub token configured")
                            .foregroundStyle(.orange)
                        Text("Add a token in Settings to access private repositories and increase API limits.")
                            .font(.caption)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Add Repository")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addRepository()
                    }
                    .disabled(repositoryURL.isEmpty)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Fetching repository...")
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(radius: 4)
                }
            }
        }
    }

    private func addRepository() {
        guard let components = repositoryURL.githubRepoComponents else {
            errorMessage = "Invalid GitHub URL"
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Use global token from settings
                let token = settings.first?.githubToken
                let gitHubService = GitHubService(token: token)
                let repoInfo = try await gitHubService.getRepository(
                    owner: components.owner,
                    name: components.name
                )

                await MainActor.run {
                    let repository = GitHubRepository(
                        name: repoInfo.name,
                        owner: repoInfo.owner.login,
                        url: repoInfo.htmlUrl,
                        isPrivate: repoInfo.private,
                        defaultBranch: repoInfo.defaultBranch
                    )

                    modelContext.insert(repository)
                    try? modelContext.save()

                    isLoading = false
                    dismiss()
                }
            } catch let error as GitHubAPIError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to add repository: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    AddRepositoryView()
        .modelContainer(for: [GitHubRepository.self], inMemory: true)
}
