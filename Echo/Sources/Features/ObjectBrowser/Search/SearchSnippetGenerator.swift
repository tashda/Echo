import Foundation

/// Consolidated snippet generator for search results.
/// Extracts a window of text around the first match, normalizes whitespace,
/// and adds ellipsis markers at truncation boundaries.
enum SearchSnippetGenerator {
    static func makeSnippet(from text: String, matching query: String, radius: Int = 100) -> String? {
        guard !text.isEmpty, !query.isEmpty else { return nil }

        guard let matchRange = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return nil
        }

        let lowerBound = text.index(matchRange.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let upperBound = text.index(matchRange.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex

        var snippet = String(text[lowerBound..<upperBound])
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: " ")
        while snippet.contains("  ") {
            snippet = snippet.replacingOccurrences(of: "  ", with: " ")
        }
        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)

        if lowerBound > text.startIndex {
            snippet = "…" + snippet
        }
        if upperBound < text.endIndex {
            snippet += "…"
        }

        return snippet
    }
}
