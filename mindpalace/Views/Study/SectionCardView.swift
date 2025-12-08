import SwiftUI
import SwiftData
import MarkdownUI

struct SectionCardView: View {
    let section: MarkdownSection
    let viewModel: StudyViewModel
    let onReviewed: () -> Void

    @State private var showingFullDocument = false

    // Helper function for level colors
    private func levelColor(for level: Int) -> Color {
        switch level {
        case 1: return .blue
        case 2: return .green
        case 3: return .orange
        case 4: return .purple
        default: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact Header with toolbar
            HStack(spacing: 8) {
                // Title and context info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        // Context badge
                        if viewModel.isShowingFullDocument {
                            Image(systemName: "list.bullet.rectangle")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        } else if viewModel.isShowingContext {
                            Image(systemName: "arrow.up.doc")
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        Text(section.title)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }

                    // Metadata row
                    HStack(spacing: 8) {
                        if let fileName = section.file?.fileName {
                            Text(fileName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.navigationStack.isEmpty,
                           let originalSection = viewModel.getOriginalSection() {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Image(systemName: "target")
                                    .font(.caption2)
                                Text(originalSection.title)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                            .lineLimit(1)
                        }

                        // Statistics
                        if let stats = viewModel.statistics {
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption2)
                                Text("\(stats.reviewedToday)/\(stats.dailyGoal)")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                        }
                    }
                }

                Spacer()

                // Compact navigation buttons
                HStack(spacing: 8) {
                    if viewModel.canNavigateBack() {
                        Button {
                            viewModel.navigateBack()
                        } label: {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                    }

                    if viewModel.canNavigateUp() {
                        Button {
                            viewModel.navigateToParent()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                        }
                    }

                    Button {
                        showingFullDocument = true
                    } label: {
                        Image(systemName: "list.bullet.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            Divider()

            // Content - takes all available space
            if viewModel.isShowingFullDocument {
                // Show interactive table of contents
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        // List of sections - compact version
                        ForEach(viewModel.getFileSections()) { tocSection in
                            Button {
                                viewModel.navigateToSection(tocSection)
                            } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    // Level indicator with color
                                    Circle()
                                        .fill(levelColor(for: tocSection.level))
                                        .frame(width: 8, height: 8)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(tocSection.title)
                                            .font(.subheadline)
                                            .fontWeight(tocSection.level == 1 ? .semibold : .regular)
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        if !tocSection.content.isEmpty {
                                            Text(tocSection.content.prefix(80) + (tocSection.content.count > 80 ? "..." : ""))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer(minLength: 4)

                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.leading, CGFloat(max(0, tocSection.level - 1) * 16))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Show markdown content
                ScrollView {
                    Markdown(viewModel.getCurrentContent())
                        .markdownTheme(.gitHub)
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            HighlightedCodeBlock(configuration: configuration)
                        }
                        .markdownImageProvider(
                            GitHubImageProvider(
                                repository: section.file?.repository,
                                filePath: section.file?.path ?? "",
                                branch: section.file?.repository?.defaultBranch ?? "main"
                            )
                        )
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .frame(maxHeight: .infinity)
            }

        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottomTrailing) {
            // Floating action button
            Button {
                onReviewed()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                    Text("Got it")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.green)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .padding(16)
        }
        .sheet(isPresented: $showingFullDocument) {
            if let file = section.file {
                FullDocumentView(file: file)
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: MarkdownSection.self, configurations: config)
    let modelContext = container.mainContext

    let section = MarkdownSection(
        title: "Introduction to SwiftUI",
        content: """
        # SwiftUI Basics

        SwiftUI is Apple's modern framework for building user interfaces.

        ## Key Features
        - Declarative syntax
        - Live previews
        - Cross-platform

        ```swift
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        ```
        """,
        level: 2,
        lineStart: 10,
        lineEnd: 30
    )

    let viewModel = StudyViewModel(modelContext: modelContext)

    SectionCardView(section: section, viewModel: viewModel) {
        print("Reviewed!")
    }
}
