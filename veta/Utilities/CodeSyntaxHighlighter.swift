import Foundation
import SwiftUI
import Highlightr

struct CodeHighlighter {
    private let highlightr: Highlightr
    private let colorScheme: ColorScheme
    private let fontSize: CGFloat

    init(colorScheme: ColorScheme = .dark, fontSize: CGFloat = 14) {
        highlightr = Highlightr()!
        self.colorScheme = colorScheme
        self.fontSize = fontSize

        // Выбираем тему в зависимости от цветовой схемы
        let theme = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
        highlightr.setTheme(to: theme)
    }

    func highlight(_ code: String, language: String?) -> NSAttributedString {
        let lang = language?.lowercased() ?? "plaintext"

        guard let highlighted = highlightr.highlight(code, as: lang) else {
            // Если подсветка не удалась, возвращаем обычный текст
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: UIColor.label
            ]
            return NSAttributedString(string: code, attributes: attributes)
        }

        // Apply font size to highlighted code
        let mutableAttributedString = NSMutableAttributedString(attributedString: highlighted)
        let range = NSRange(location: 0, length: mutableAttributedString.length)

        mutableAttributedString.enumerateAttribute(.font, in: range) { value, range, _ in
            if let currentFont = value as? UIFont {
                let newFont = currentFont.withSize(fontSize)
                mutableAttributedString.addAttribute(.font, value: newFont, range: range)
            }
        }

        return mutableAttributedString
    }
}
