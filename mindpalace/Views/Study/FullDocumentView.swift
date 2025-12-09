import SwiftUI
import MarkdownUI

struct FullDocumentView: View {
    let file: MarkdownFile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var defaultOpenURL
    @State private var isLoading = true
    @State private var scrollTarget: String?
    @State private var preloadedAnchors: Set<String> = []

    // Convert section title to anchor ID (matching markdown convention)
    private func titleToAnchor(_ title: String) -> String {
        return title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
    }

    // Handle markdown link clicks
    private func handleMarkdownLink(_ url: URL, scrollProxy: ScrollViewProxy?) -> OpenURLAction.Result {
        let urlString = url.absoluteString

        // Handle anchor links (internal document links starting with #)
        if urlString.hasPrefix("#") {
            let anchor = String(urlString.dropFirst()) // Remove the #
            if !anchor.isEmpty {
                scrollTarget = anchor
                print("📍 Trying to scroll to anchor: \(anchor)")

                // Try scrolling with retries for lazy loaded content
                tryScrollToAnchor(anchor, scrollProxy: scrollProxy, attempt: 0)
            }
            return .handled
        }

        // Open external links
        if url.scheme == "http" || url.scheme == "https" {
            defaultOpenURL(url)
            return .handled
        }

        return .discarded
    }

    // Retry scrolling to anchor with delays (for lazy loading)
    private func tryScrollToAnchor(_ anchor: String, scrollProxy: ScrollViewProxy?, attempt: Int) {
        let maxAttempts = 15
        let delay = 0.15

        if preloadedAnchors.contains(anchor) {
            // Anchor is loaded, scroll immediately
            print("✅ Found anchor: \(anchor)")
            withAnimation(.easeInOut(duration: 0.3)) {
                scrollProxy?.scrollTo(anchor, anchor: .top)
            }
        } else if attempt < maxAttempts {
            // Anchor not yet loaded, find and scroll to section by matching title
            if attempt == 0 {
                // On first attempt, try to find the section and trigger its loading
                let sections = file.sections.sorted(by: { $0.orderIndex < $1.orderIndex })
                if let matchingSection = sections.first(where: { titleToAnchor($0.title) == anchor }) {
                    print("🔍 Found matching section: '\(matchingSection.title)' at index \(matchingSection.orderIndex)")
                    // Scroll to section ID to trigger lazy loading
                    scrollProxy?.scrollTo(matchingSection.id, anchor: .top)
                }
            }

            // Wait and retry
            print("⏳ Waiting for anchor \(anchor) (attempt \(attempt + 1)/\(maxAttempts))")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                tryScrollToAnchor(anchor, scrollProxy: scrollProxy, attempt: attempt + 1)
            }
        } else {
            print("❌ Could not find anchor: \(anchor)")
            print("📋 Available anchors: \(preloadedAnchors.sorted())")
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Group {
                    if isLoading {
                        VStack {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading document...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if file.sections.isEmpty {
                    // Fallback: show full content if no sections
                    ScrollViewReader { proxy in
                        ScrollView {
                            if let content = file.content {
                                Markdown(HTMLToMarkdownConverter.convertHTMLTables(in: content))
                                    .markdownTableBorderStyle(.init(color: .secondary))
                                    .markdownTableBackgroundStyle(.alternatingRows(.secondary.opacity(0.1), Color.clear))
                                    .markdownImageProvider(
                                        GitHubImageProvider(
                                            repository: file.repository,
                                            filePath: file.path,
                                            branch: file.repository?.defaultBranch ?? "main"
                                        )
                                    )
                                    .markdownBlockStyle(\.codeBlock) { configuration in
                                        HighlightedCodeBlock(configuration: configuration)
                                    }
                                    .markdownTheme(.gitHub)
                                    .environment(\.openURL, OpenURLAction { url in
                                        handleMarkdownLink(url, scrollProxy: proxy)
                                    })
                                    .padding()
                            }
                        }
                    }
                } else {
                    // Show sections with lazy loading for better performance
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(file.sections.sorted(by: { $0.orderIndex < $1.orderIndex })) { section in
                                    VStack(alignment: .leading, spacing: 0) {
                                        // Section header with id for anchor navigation
                                        HStack {
                                            Text(section.title)
                                                .font(.headline)
                                                .padding(.horizontal)
                                                .padding(.vertical, 8)
                                            Spacer()
                                        }
                                        .background(Color(.secondarySystemBackground))
                                        .id(titleToAnchor(section.title))
                                        .onAppear {
                                            let anchor = titleToAnchor(section.title)
                                            preloadedAnchors.insert(anchor)
                                            print("📌 Section registered with id: \(anchor)")
                                        }

                                        // Section content
                                        Markdown(HTMLToMarkdownConverter.convertHTMLTables(in: section.content))
                                            .markdownTableBorderStyle(.init(color: .secondary))
                                            .markdownTableBackgroundStyle(.alternatingRows(.secondary.opacity(0.1), Color.clear))
                                            .markdownImageProvider(
                                                GitHubImageProvider(
                                                    repository: file.repository,
                                                    filePath: file.path,
                                                    branch: file.repository?.defaultBranch ?? "main"
                                                )
                                            )
                                            .markdownBlockStyle(\.codeBlock) { configuration in
                                                HighlightedCodeBlock(configuration: configuration)
                                            }
                                            .markdownTheme(.gitHub)
                                            .environment(\.openURL, OpenURLAction { url in
                                                handleMarkdownLink(url, scrollProxy: proxy)
                                            })
                                            .padding()
                                    }

                                    Divider()
                                }
                            }
                        }
                    }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isLoading)

                // Floating close button
                if !isLoading {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white, .gray.opacity(0.8))
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 32, height: 32)
                            )
                    }
                    .padding()
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }
            }
        }
        .navigationTitle(file.fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .task {
            // Simulate loading delay for smooth transition
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            withAnimation(.easeInOut(duration: 0.2)) {
                isLoading = false
            }
        }
    }
}

#Preview {
    let file = MarkdownFile(
        path: "example.md",
        fileName: "example.md",
        content: """
        # Full Document

        This is the full document content.

        ## Section 1
        Content for section 1

        ## Section 2
        Content for section 2
        """
    )

    return FullDocumentView(file: file)
}
