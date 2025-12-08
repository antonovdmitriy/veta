import Foundation

struct ParsedSection {
    let title: String
    let content: String
    let level: Int
    let lineStart: Int
    let lineEnd: Int
    let orderIndex: Int
}

class MarkdownParser {

    /// Parses markdown content into sections based on headings
    func parse(content: String) -> [ParsedSection] {
        let lines = content.components(separatedBy: .newlines)
        var sections: [ParsedSection] = []
        var currentSection: (title: String, level: Int, startLine: Int, contentLines: [String])? = nil
        var orderIndex = 0

        for (index, line) in lines.enumerated() {
            if let heading = parseHeading(line) {
                // Save previous section if exists
                if let section = currentSection {
                    let content = section.contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                    sections.append(ParsedSection(
                        title: section.title,
                        content: content,
                        level: section.level,
                        lineStart: section.startLine,
                        lineEnd: index - 1,
                        orderIndex: orderIndex
                    ))
                    orderIndex += 1
                }

                // Start new section
                currentSection = (
                    title: heading.title,
                    level: heading.level,
                    startLine: index,
                    contentLines: []
                )
            } else if currentSection != nil {
                // Add line to current section
                currentSection?.contentLines.append(line)
            }
        }

        // Save last section
        if let section = currentSection {
            let content = section.contentLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            sections.append(ParsedSection(
                title: section.title,
                content: content,
                level: section.level,
                lineStart: section.startLine,
                lineEnd: lines.count - 1,
                orderIndex: orderIndex
            ))
        }

        return sections
    }

    /// Parses a heading line and returns its level and title
    private func parseHeading(_ line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // ATX-style headings (# Heading)
        if trimmed.hasPrefix("#") {
            let components = trimmed.split(separator: " ", maxSplits: 1)
            guard let first = components.first else { return nil }

            let level = first.filter { $0 == "#" }.count
            guard Constants.Markdown.headingLevels.contains(level) else { return nil }

            let title = components.count > 1 ? String(components[1]) : ""
            return (level: level, title: title)
        }

        return nil
    }

    /// Extracts image paths from markdown content
    func extractImagePaths(from content: String) -> [String] {
        var imagePaths: [String] = []

        // Regex for markdown images: ![alt](path)
        let pattern = #"!\[([^\]]*)\]\(([^\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)

        for match in matches {
            if match.numberOfRanges >= 3,
               let pathRange = Range(match.range(at: 2), in: content) {
                let path = String(content[pathRange])
                imagePaths.append(path)
            }
        }

        return imagePaths
    }

    /// Resolves relative image paths to absolute URLs
    func resolveImagePath(_ path: String, baseURL: String, owner: String, repo: String, branch: String = "main") -> String {
        // If already an absolute URL, return as is
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return path
        }

        // Resolve relative path
        if path.hasPrefix("./") {
            let cleanPath = String(path.dropFirst(2))
            return "\(Constants.GitHub.rawContentURL)/\(owner)/\(repo)/\(branch)/\(cleanPath)"
        } else if path.hasPrefix("/") {
            return "\(Constants.GitHub.rawContentURL)/\(owner)/\(repo)/\(branch)\(path)"
        } else {
            // Relative to current file
            return "\(Constants.GitHub.rawContentURL)/\(owner)/\(repo)/\(branch)/\(path)"
        }
    }

    /// Converts markdown sections to MarkdownSection models
    func createSections(from parsed: [ParsedSection], file: MarkdownFile) -> [MarkdownSection] {
        return parsed.map { section in
            MarkdownSection(
                title: section.title,
                content: section.content,
                level: section.level,
                lineStart: section.lineStart,
                lineEnd: section.lineEnd,
                orderIndex: section.orderIndex,
                file: file
            )
        }
    }
}
