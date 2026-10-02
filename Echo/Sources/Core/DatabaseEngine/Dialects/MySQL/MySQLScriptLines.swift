import Foundation

/// Where the statements `MySQLScript.statements` found start in the editor's text, for the
/// script's statement list and error marks (#36).
nonisolated enum MySQLScriptLines {
    /// Whether the script changes the delimiter (`DELIMITER $$`): a client command, never sent.
    static func hasDelimiterCommand(_ sql: String) -> Bool {
        sql.split(whereSeparator: \.isNewline).contains { line in
            line.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("DELIMITER ")
        }
    }

    /// The zero-based line each statement starts on: its first line, looked for in order. When a
    /// comment the splitter dropped hides it, the previous statement's line.
    static func startLines(of statements: [String], in sql: String) -> [Int] {
        var lines: [Int] = []
        var searchStart = sql.startIndex
        var line = 0
        for statement in statements {
            let firstLine = statement.split(whereSeparator: \.isNewline).first.map(String.init) ?? statement
            if let range = sql.range(of: firstLine, range: searchStart..<sql.endIndex) {
                line = sql[..<range.lowerBound].reduce(0) { $1 == "\n" ? $0 + 1 : $0 }
                searchStart = range.upperBound
            }
            lines.append(line)
        }
        return lines
    }
}
