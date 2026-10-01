import Foundation

/// Round 43.5 (PC0): finds UPDATE and DELETE statements that have no WHERE, for connections that
/// ask before running them. Comments and quoted text are ignored; it is a guard rail, not a parser.
nonisolated enum UnguardedWriteDetector {
    /// The first words of each flagged statement, in order.
    static func unguardedStatements(in sql: String) -> [String] {
        statements(of: strip(sql)).compactMap { statement in
            let words = statement.split(whereSeparator: \.isWhitespace).map { $0.lowercased() }
            guard let first = words.first, first == "update" || first == "delete" else { return nil }
            return words.contains("where") ? nil : statement
        }
    }

    private static func statements(of text: String) -> [String] {
        text.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The text with comments removed and quoted text blanked.
    private static func strip(_ sql: String) -> String {
        var result = ""
        var index = sql.startIndex
        while index < sql.endIndex {
            let rest = sql[index...]
            if rest.hasPrefix("--") {
                index = sql[index...].firstIndex(of: "\n") ?? sql.endIndex
            } else if rest.hasPrefix("/*") {
                if let close = sql.range(of: "*/", range: index..<sql.endIndex) { index = close.upperBound } else { index = sql.endIndex }
            } else if let quote = sql[index...].first, quote == "'" || quote == "\"" {
                var cursor = sql.index(after: index)
                while cursor < sql.endIndex {
                    if sql[cursor] == quote {
                        let next = sql.index(after: cursor)
                        if next < sql.endIndex, sql[next] == quote { cursor = sql.index(after: next); continue }
                        break
                    }
                    cursor = sql.index(after: cursor)
                }
                result += " x "
                index = cursor < sql.endIndex ? sql.index(after: cursor) : sql.endIndex
            } else {
                result.append(sql[index])
                index = sql.index(after: index)
            }
        }
        return result
    }
}
