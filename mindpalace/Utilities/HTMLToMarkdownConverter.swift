import Foundation

struct HTMLToMarkdownConverter {

    /// Converts HTML tables to Markdown tables and normalizes existing Markdown tables
    static func convertHTMLTables(in markdown: String) -> String {
        var result = markdown

        // First, convert Markdown tables to HTML tables
        result = convertMarkdownTablesToHTML(result)

        // Find all HTML tables
        let tablePattern = #"<table[^>]*>([\s\S]*?)</table>"#
        guard let tableRegex = try? NSRegularExpression(pattern: tablePattern, options: [.caseInsensitive]) else {
            return markdown
        }

        let matches = tableRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))

        // Process matches in reverse order to preserve indices
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            let tableHTML = String(result[range])

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

    /// Converts Markdown tables to HTML tables
    private static func convertMarkdownTablesToHTML(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var result: [String] = []
        var tableLines: [String] = []
        var inTable = false

        var i = 0
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let isTableLine = trimmed.hasPrefix("|") && trimmed.hasSuffix("|")

            if isTableLine {
                inTable = true
                tableLines.append(trimmed)
                i += 1

                // Skip empty lines between table rows
                while i < lines.count && lines[i].trimmingCharacters(in: .whitespaces).isEmpty {
                    i += 1
                }
            } else {
                if inTable && !tableLines.isEmpty {
                    // Convert collected Markdown table to HTML
                    let htmlTable = markdownTableToHTML(tableLines)
                    result.append(htmlTable)
                    tableLines.removeAll()
                }
                inTable = false
                result.append(line)
                i += 1
            }
        }

        // Handle table at end of document
        if !tableLines.isEmpty {
            let htmlTable = markdownTableToHTML(tableLines)
            result.append(htmlTable)
        }

        return result.joined(separator: "\n")
    }

    /// Converts a Markdown table to HTML table
    private static func markdownTableToHTML(_ tableLines: [String]) -> String {
        guard tableLines.count >= 2 else { return tableLines.joined(separator: "\n") }

        var html = "<table>"

        for (index, line) in tableLines.enumerated() {
            // Skip separator line (line with ---)
            if line.contains("---") || line.contains(":-") || line.contains("-:") {
                continue
            }

            // Parse cells
            let cells = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let cellTag = (index == 0) ? "th" : "td"

            html += "<tr>"
            for cell in cells {
                html += "<\(cellTag)>\(cell)</\(cellTag)>"
            }
            html += "</tr>"
        }

        html += "</table>"
        return html
    }
}
