import Foundation
import SwiftUI
import Highlightr

struct CodeHighlighter {
    private let highlightr: Highlightr

    init() {
        highlightr = Highlightr()!
        highlightr.setTheme(to: "atom-one-dark")
    }

    func highlight(_ code: String, language: String?) -> NSAttributedString {
        let lang = language?.lowercased() ?? "plaintext"

        guard let highlighted = highlightr.highlight(code, as: lang) else {
            // Если подсветка не удалась, возвращаем обычный текст
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            return NSAttributedString(string: code, attributes: attributes)
        }

        return highlighted
    }
}
