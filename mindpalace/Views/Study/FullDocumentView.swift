import SwiftUI
import MarkdownUI

struct FullDocumentView: View {
    let file: MarkdownFile
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if file.sections.isEmpty {
                // Fallback: show full content if no sections
                ScrollView {
                    if let content = file.content {
                        Markdown(content)
                            .markdownTheme(.gitHub)
                            .markdownImageProvider(
                                GitHubImageProvider(
                                    repository: file.repository,
                                    filePath: file.path,
                                    branch: file.repository?.defaultBranch ?? "main"
                                )
                            )
                            .padding()
                    }
                }
            } else {
                // Show sections with lazy loading for better performance
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(file.sections.sorted(by: { $0.orderIndex < $1.orderIndex })) { section in
                            Section {
                                Markdown(section.content)
                                    .markdownTheme(.gitHub)
                                    .markdownImageProvider(
                                        GitHubImageProvider(
                                            repository: file.repository,
                                            filePath: file.path,
                                            branch: file.repository?.defaultBranch ?? "main"
                                        )
                                    )
                                    .padding()
                            } header: {
                                HStack {
                                    Text(section.title)
                                        .font(.headline)
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    Spacer()
                                }
                                .background(Color(.secondarySystemBackground))
                            }

                            Divider()
                        }
                    }
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
