import SwiftUI
import SwiftData
import MarkdownUI

struct StudyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: StudyViewModel?
    @State private var currentSection: MarkdownSection?
    @State private var showingEmptyState = false

    var body: some View {
        NavigationStack {
            Group {
                if let section = currentSection, let vm = viewModel {
                    SectionCardView(
                        section: section,
                        viewModel: vm,
                        onReviewed: {
                            handleReviewed()
                        },
                        onIgnored: {
                            handleIgnored()
                        }
                    )
                    .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    .id(section.id) // Force view recreation for new section
                } else if showingEmptyState {
                    emptyStateView
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if viewModel == nil {
                    viewModel = StudyViewModel(modelContext: modelContext)
                }
                loadNextSection()
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Sections to Review")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add repositories from the Repositories tab to get started.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    private func loadNextSection() {
        guard let viewModel = viewModel else { return }

        // Clear current section immediately to show loading state
        currentSection = nil

        // Load next section - runs on MainActor so no Sendable issues
        Task { @MainActor in
            let section = viewModel.getNextSection()
            withAnimation(.easeInOut(duration: 0.15)) {
                currentSection = section
                showingEmptyState = section == nil
            }
        }
    }

    private func handleReviewed() {
        guard let viewModel = viewModel else { return }

        // Get the original section that was being reviewed (before navigation)
        let sectionToReview = viewModel.getOriginalSection() ?? currentSection

        guard let section = sectionToReview else { return }

        // Mark as reviewed (stays on MainActor)
        Task { @MainActor in
            viewModel.markAsReviewed(section: section)
        }

        // Load next section immediately
        loadNextSection()
    }

    private func handleIgnored() {
        guard let section = currentSection else { return }

        // Mark as ignored (stays on MainActor)
        Task { @MainActor in
            section.isIgnored = true
            try? modelContext.save()
        }

        // Load next section immediately
        loadNextSection()
    }
}

#Preview {
    StudyView()
        .modelContainer(for: [
            GitHubRepository.self,
            MarkdownFile.self,
            MarkdownSection.self,
            RepetitionRecord.self
        ], inMemory: true)
}
