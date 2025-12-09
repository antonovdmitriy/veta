import SwiftUI
import SwiftData
import MarkdownUI

struct SectionCardView: View {
    @Bindable var section: MarkdownSection
    let viewModel: StudyViewModel
    let onReviewed: () -> Void
    let onIgnored: () -> Void

    @State private var showingFullDocument = false
    @State private var showingIgnoreConfirmation = false
    @State private var isMenuVisible = true
    @Environment(\.openURL) private var defaultOpenURL

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

    // Handle markdown link clicks
    private func handleMarkdownLink(_ url: URL) -> OpenURLAction.Result {
        let urlString = url.absoluteString

        // Handle anchor links (internal document links starting with #)
        if urlString.hasPrefix("#") {
            handleAnchorLink(urlString)
            return .handled
        }

        // Open external links
        if url.scheme == "http" || url.scheme == "https" {
            defaultOpenURL(url)
            return .handled
        }

        return .discarded
    }

    // Navigate to section via anchor link
    private func handleAnchorLink(_ urlString: String) {
        let anchor = String(urlString.dropFirst()) // Remove the '#'

        // Decode URL-encoded anchor (e.g., %D0%BB%D1%8E%D0%B4%D0%BE%D0%B2%D0%B8%D0%BA)
        guard let decodedAnchor = anchor.removingPercentEncoding else {
            return
        }

        // Find section by anchor in the current file
        let fileSections = viewModel.getFileSections()
        let normalizedAnchor = decodedAnchor.lowercased()

        if let targetSection = fileSections.first(where: { section in
            let sectionAnchor = generateAnchor(from: section.title)
            return sectionAnchor == normalizedAnchor
        }) {
            viewModel.navigateToSection(targetSection)
        }
    }

    // Generate anchor from title (matches GitHub's anchor format)
    private func generateAnchor(from title: String) -> String {
        return title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ")).inverted)
            .joined()
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
                    // Favorite star button
                    Button {
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()

                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            section.isFavoriteSection.toggle()
                        }
                        try? viewModel.modelContext.save()
                    } label: {
                        Image(systemName: section.isFavoriteSection ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(section.isFavoriteSection ? .yellow : .secondary)
                            .symbolEffect(.bounce, value: section.isFavoriteSection)
                    }

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
                ZStack {
                    ScrollView {
                        Markdown(viewModel.getCurrentContent())
                            .markdownTableBorderStyle(.init(color: .secondary))
                        .markdownTableBackgroundStyle(.alternatingRows(.secondary.opacity(0.1), Color.clear))
                        .markdownImageProvider(
                            GitHubImageProvider(
                                repository: section.file?.repository,
                                filePath: section.file?.path ?? "",
                                branch: section.file?.repository?.defaultBranch ?? "main"
                            )
                        )
                        .markdownBlockStyle(\.codeBlock) { configuration in
                            HighlightedCodeBlock(configuration: configuration)
                        }
                        .markdownTheme(.gitHub)
                        .environment(\.openURL, OpenURLAction { url in
                            handleMarkdownLink(url)
                        })
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: .infinity)
                }
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            // Swipe down to hide menu, swipe up to show menu
                            if value.translation.height > 50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isMenuVisible = false
                                }
                            } else if value.translation.height < -50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isMenuVisible = true
                                }
                            }
                        }
                )
            }

        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            // Show menu indicator when hidden
            if !isMenuVisible {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMenuVisible = true
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(Color.blue.opacity(0.8))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if isMenuVisible {
                // Floating action buttons
                HStack(spacing: 12) {
                // Ignore button
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    showingIgnoreConfirmation = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                        Text("Ignore")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.6, blue: 0.2), Color(red: 1.0, green: 0.45, blue: 0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }

                // Got it button
                Button {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
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
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.7, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                }
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showingFullDocument) {
            if let file = section.file {
                FullDocumentView(file: file)
            }
        }
        .alert("Ignore This Section?", isPresented: $showingIgnoreConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Ignore", role: .destructive) {
                onIgnored()
            }
        } message: {
            Text("This section will no longer appear in your study sessions. You can unignore it later in Settings.")
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

    SectionCardView(
        section: section,
        viewModel: viewModel,
        onReviewed: {
            print("Reviewed!")
        },
        onIgnored: {
            print("Ignored!")
        }
    )
}
