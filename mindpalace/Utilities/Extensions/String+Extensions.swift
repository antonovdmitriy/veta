import Foundation
import CryptoKit

extension String {
    /// Returns SHA256 hash of the string
    var sha256: String {
        let data = Data(self.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Returns true if string is a valid URL
    var isValidURL: Bool {
        guard let url = URL(string: self) else { return false }
        return url.scheme != nil && url.host != nil
    }

    /// Extracts owner and repo name from GitHub URL
    /// Example: "https://github.com/owner/repo" -> ("owner", "repo")
    var githubRepoComponents: (owner: String, name: String)? {
        guard let url = URL(string: self) else { return nil }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard pathComponents.count >= 2 else { return nil }

        return (owner: pathComponents[0], name: pathComponents[1])
    }

    /// Returns true if this is a markdown file
    var isMarkdownFile: Bool {
        let ext = (self as NSString).pathExtension.lowercased()
        return Constants.Markdown.supportedExtensions.contains(ext)
    }

    /// Removes markdown formatting for plain text
    var withoutMarkdownFormatting: String {
        var text = self
        // Remove headers
        text = text.replacingOccurrences(of: #"^#+\s+"#, with: "", options: .regularExpression)
        // Remove bold/italic
        text = text.replacingOccurrences(of: #"[*_]{1,2}"#, with: "", options: .regularExpression)
        // Remove links
        text = text.replacingOccurrences(of: #"\[([^\]]+)\]\([^\)]+\)"#, with: "$1", options: .regularExpression)
        // Remove code
        text = text.replacingOccurrences(of: #"`+[^`]+`+"#, with: "", options: .regularExpression)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
