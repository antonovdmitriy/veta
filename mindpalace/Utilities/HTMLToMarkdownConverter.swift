import Foundation

struct HTMLToMarkdownConverter {

    /// Converts HTML tables to Markdown tables
    static func convertHTMLTables(in markdown: String) -> String {
        var result = markdown

        // Find all HTML tables
        let tablePattern = #"<table[^>]*>([\s\S]*?)</table>"#
        guard let tableRegex = try? NSRegularExpression(pattern: tablePattern, options: [.caseInsensitive]) else {
            return markdown
        }

        let matches = tableRegex.matches(in: markdown, range: NSRange(markdown.startIndex..., in: markdown))

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: markdown) else { continue }
            let tableHTML = String(markdown[range])

            if let markdownTable = convertTableToMarkdown(tableHTML) {
                result.replaceSubrange(range, with: markdownTable)
            }
        }

        return result
    }

    /// Converts a single HTML table to Markdown table
    private static func convertTableToMarkdown(_ html: String) -> String? {
        // Extract table rows
        let rows = extractTableRows(from: html)
        guard !rows.isEmpty else { return nil }

        var markdownLines: [String] = []

        // Process header row (first row or <thead>)
        if let headerRow = rows.first {
            let headers = extractCells(from: headerRow, isHeader: true)
            if !headers.isEmpty {
                markdownLines.append("| " + headers.joined(separator: " | ") + " |")
                markdownLines.append("| " + headers.map { _ in "---" }.joined(separator: " | ") + " |")
            }
        }

        // Process data rows
        for row in rows.dropFirst() {
            let cells = extractCells(from: row, isHeader: false)
            if !cells.isEmpty {
                markdownLines.append("| " + cells.joined(separator: " | ") + " |")
            }
        }

        return markdownLines.isEmpty ? nil : "\n" + markdownLines.joined(separator: "\n") + "\n"
    }

    /// Extracts table rows from HTML
    private static func extractTableRows(from html: String) -> [String] {
        var rows: [String] = []

        // Pattern for table rows
        let rowPattern = #"<tr[^>]*>([\s\S]*?)</tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: [.caseInsensitive]) else {
            return rows
        }

        let matches = rowRegex.matches(in: html, range: NSRange(html.startIndex..., in: html))

        for match in matches {
            if let range = Range(match.range(at: 1), in: html) {
                rows.append(String(html[range]))
            }
        }

        return rows
    }

    /// Extracts cell content from a table row
    private static func extractCells(from row: String, isHeader: Bool) -> [String] {
        var cells: [String] = []

        // Pattern for table cells (th or td)
        let cellTag = isHeader ? "th" : "td"
        let cellPattern = "<\(cellTag)[^>]*>([\\s\\S]*?)</\(cellTag)>"

        guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: [.caseInsensitive]) else {
            return cells
        }

        let matches = cellRegex.matches(in: row, range: NSRange(row.startIndex..., in: row))

        for match in matches {
            if let range = Range(match.range(at: 1), in: row) {
                let cellContent = String(row[range])
                let cleaned = cleanHTMLContent(cellContent)
                cells.append(cleaned)
            }
        }

        return cells
    }

    /// Removes HTML tags and decodes HTML entities
    private static func cleanHTMLContent(_ html: String) -> String {
        var cleaned = html

        // Remove HTML tags
        cleaned = cleaned.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)

        // Decode common HTML entities
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&lt;": "<",
            "&gt;": ">",
            "&amp;": "&",
            "&quot;": "\"",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–"
        ]

        for (entity, replacement) in entities {
            cleaned = cleaned.replacingOccurrences(of: entity, with: replacement)
        }

        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // Escape pipe characters in cell content
        cleaned = cleaned.replacingOccurrences(of: "|", with: "\\|")

        return cleaned
    }
}
