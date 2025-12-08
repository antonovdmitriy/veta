import SwiftUI
import MarkdownUI
import UIKit

// UIViewRepresentable для отображения NSAttributedString с сохранением цветов
struct AttributedText: UIViewRepresentable {
    let attributedString: NSAttributedString

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.attributedText = attributedString
    }
}

struct HighlightedCodeBlock: View {
    let configuration: CodeBlockConfiguration
    let highlighter = CodeHighlighter()

    var body: some View {
        let _ = print("📦 HighlightedCodeBlock создан! Язык: \(configuration.language ?? "нет")")

        VStack(alignment: .leading, spacing: 0) {
            // Заголовок с языком
            if let language = configuration.language, !language.isEmpty {
                HStack {
                    Text(language.uppercased())
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray5))
            }

            // Блок с кодом
            ScrollView(.horizontal, showsIndicators: true) {
                AttributedText(attributedString: highlighter.highlight(configuration.content, language: configuration.language))
                    .padding(12)
            }
            .background(Color(UIColor.systemGray6))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(UIColor.systemGray4), lineWidth: 1)
        )
    }
}
