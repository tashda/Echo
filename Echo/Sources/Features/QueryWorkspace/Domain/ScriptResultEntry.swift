import EchoSense
import Foundation

/// One statement of a script in the results' statement list (Echo Labs round 21, script results:
/// SR4 list at the left, SL3 labels, SC2 command entries, SK2 editor link).
nonisolated struct ScriptResultEntry: Identifiable, Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        /// Rows; `resultSetIndex` is the result set's index in the tab (0 is the primary grid).
        case rows(resultSetIndex: Int, count: Int)
        /// A command with its tag, `INSERT 0 2`.
        case command(tag: String)
        case failed(message: String)
    }

    /// The statement's position in the script (0-based).
    let id: Int
    let label: String
    let outcome: Outcome
    let duration: TimeInterval?
    /// The statement's range in the editor, when it could be found.
    let editorRange: NSRange?

    var isFailure: Bool { if case .failed = outcome { true } else { false } }

    /// The line Messages shows for the statement (SP2): `3 · UPDATE 3 · 12 ms`.
    var messageLine: String {
        let number = id + 1
        switch outcome {
        case .rows(_, let count):
            return "\(number) · \(count) \(count == 1 ? "row" : "rows")" + (duration.map { " · \(QueryRunNote.formatted($0))" } ?? "")
        case .command(let tag):
            return "\(number) · \(tag)" + (duration.map { " · \(QueryRunNote.formatted($0))" } ?? "")
        case .failed(let message):
            return "\(number) · ERROR: \(message)"
        }
    }

    // MARK: - Labels

    /// SL3, the statement's first words: `SELECT … FROM customers`, `UPDATE orders SET`, `CREATE TEMP TABLE`.
    static func label(for sql: String) -> String {
        let words = significantWords(sql)
        guard let first = words.first else { return "Statement" }
        let upper = words.map { $0.uppercased() }
        if ["SELECT", "WITH", "TABLE", "VALUES"].contains(upper[0]), let from = upper.firstIndex(of: "FROM"), from + 1 < words.count {
            return clipped("\(first.uppercased()) … FROM \(trimmedIdentifier(words[from + 1]))")
        }
        return clipped(words.prefix(3).enumerated().map { index, word in
            ScriptResultEntry.keywords.contains(word.uppercased()) ? word.uppercased() : (index == 0 ? word.uppercased() : word)
        }.joined(separator: " "))
    }

    private static let keywords: Set<String> = [
        "SELECT", "INSERT", "INTO", "UPDATE", "DELETE", "FROM", "CREATE", "TEMP", "TEMPORARY", "TABLE", "INDEX",
        "VIEW", "DROP", "ALTER", "SET", "BEGIN", "COMMIT", "ROLLBACK", "GRANT", "REVOKE", "TRUNCATE", "VACUUM",
        "ANALYZE", "WITH", "VALUES", "OR", "REPLACE", "FUNCTION", "SCHEMA", "IF", "EXISTS", "NOT", "ON", "COPY",
    ]

    private static func clipped(_ text: String) -> String {
        text.count > 48 ? String(text.prefix(47)) + "…" : text
    }

    private static func trimmedIdentifier(_ word: String) -> String {
        String(word.prefix { $0 != "(" && $0 != "," && $0 != ";" && $0 != ")" })
    }

    /// Words of the statement without comments.
    private static func significantWords(_ sql: String) -> [String] {
        var text = ""
        var index = sql.startIndex
        while index < sql.endIndex {
            let rest = sql[index...]
            if rest.hasPrefix("--") {
                index = rest.firstIndex(of: "\n") ?? sql.endIndex
            } else if rest.hasPrefix("/*") {
                index = rest.range(of: "*/").map(\.upperBound) ?? sql.endIndex
                text.append(" ")
            } else {
                text.append(sql[index]); index = sql.index(after: index)
            }
        }
        return text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    // MARK: - Editor ranges

    /// Finds each statement's range in the editor text, in order, within the range that ran.
    static func editorRanges(for statements: [String], in editorText: String, within runRange: NSRange?) -> [NSRange?] {
        let text = editorText as NSString
        var cursor = runRange?.location ?? 0
        let end = runRange.map { min(NSMaxRange($0), text.length) } ?? text.length
        return statements.map { statement in
            let needle = statement.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !needle.isEmpty, cursor < end else { return nil }
            let found = text.range(of: needle, options: [], range: NSRange(location: cursor, length: end - cursor))
            guard found.location != NSNotFound else { return nil }
            cursor = NSMaxRange(found)
            return found
        }
    }

    /// The entries for a finished script: statements that did not run are left out (Messages says so).
    static func entries(for results: [BatchResult], statements: [String], editorRanges: [NSRange?]) -> [ScriptResultEntry] {
        var resultSetIndex = 0
        var entries: [ScriptResultEntry] = []
        for result in results where !result.skipped {
            let index = result.batchIndex
            let sql = index < statements.count ? statements[index] : ""
            let outcome: Outcome
            if let error = result.error {
                outcome = .failed(message: error)
            } else if let set = result.resultSets.first {
                outcome = .rows(resultSetIndex: resultSetIndex, count: set.totalRowCount ?? set.rows.count)
                resultSetIndex += result.resultSets.count
            } else {
                outcome = .command(tag: result.messages.first?.message ?? "Done")
            }
            entries.append(ScriptResultEntry(
                id: index, label: label(for: sql), outcome: outcome, duration: result.duration,
                editorRange: index < editorRanges.count ? editorRanges[index] : nil
            ))
        }
        return entries
    }
}

extension QueryEditorState {
    /// Selects a statement in the list: its rows show in the grid and its statement lights up in the editor.
    func selectScriptEntry(_ entry: ScriptResultEntry) {
        selectedScriptEntryID = entry.id
        highlightedStatementRange = entry.editorRange
        if case .rows(let index, _) = entry.outcome { selectedResultSetIndex = index }
    }

    var selectedScriptEntry: ScriptResultEntry? {
        scriptEntries?.first { $0.id == selectedScriptEntryID }
    }
}
