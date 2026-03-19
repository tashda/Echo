import Foundation

/// Splits a T-SQL batch into individual executable statements, respecting string
/// literals, comments, nested blocks (BEGIN…END, IF…ELSE), and GO separators.
nonisolated struct TSQLStatementSplitter: Sendable {
    struct Statement: Sendable, Equatable {
        let text: String
        let range: Range<String.Index>
        let lineNumber: Int
    }

    /// Variables detected from DECLARE / SET statements in the batch.
    struct VariableReference: Sendable, Equatable {
        let name: String
        /// The line where the variable was first declared or set.
        let lineNumber: Int
    }

    // MARK: - Public API

    static func split(_ sql: String) -> [Statement] {
        let batches = splitByGO(sql)
        var statements: [Statement] = []
        for batch in batches {
            statements.append(contentsOf: splitBatch(batch.text, batchStart: batch.range.lowerBound, baseLineNumber: batch.lineNumber, in: sql))
        }
        return statements
    }

    /// Extract all variable names referenced via DECLARE or SET in the given SQL.
    static func extractVariables(from sql: String) -> [VariableReference] {
        var variables: [VariableReference] = []
        var seen: Set<String> = []
        let lines = sql.components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces).uppercased()
            if trimmed.hasPrefix("DECLARE") || trimmed.hasPrefix("SET") {
                for name in extractVariableNames(from: line) {
                    let uppercased = name.uppercased()
                    if !seen.contains(uppercased) {
                        seen.insert(uppercased)
                        variables.append(VariableReference(name: name, lineNumber: index + 1))
                    }
                }
            }
        }
        return variables
    }

    // MARK: - GO Splitting

    private static func splitByGO(_ sql: String) -> [Statement] {
        var batches: [Statement] = []
        var currentStart = sql.startIndex
        var currentLine = 1
        var i = sql.startIndex

        while i < sql.endIndex {
            let ch = sql[i]

            // Skip string literals
            if ch == "'" {
                i = skipStringLiteral(in: sql, from: i)
                continue
            }

            // Skip block comments
            if ch == "/" && sql.index(after: i) < sql.endIndex && sql[sql.index(after: i)] == "*" {
                i = skipBlockComment(in: sql, from: i)
                continue
            }

            // Skip line comments
            if ch == "-" && sql.index(after: i) < sql.endIndex && sql[sql.index(after: i)] == "-" {
                i = skipLineComment(in: sql, from: i)
                continue
            }

            // Check for GO at the start of a line (case-insensitive, standalone)
            if isLineStart(in: sql, at: i) && matchesGO(in: sql, at: i) {
                let batchText = String(sql[currentStart..<i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !batchText.isEmpty {
                    batches.append(Statement(text: batchText, range: currentStart..<i, lineNumber: currentLine))
                }
                // Skip past GO and any trailing whitespace/newline
                let goEnd = skipGO(in: sql, from: i)
                currentLine = lineNumber(in: sql, upTo: goEnd)
                currentStart = goEnd
                i = goEnd
                continue
            }

            if ch == "\n" {
                // line counting handled by lineNumber helper
            }

            i = sql.index(after: i)
        }

        // Remaining batch
        let remaining = String(sql[currentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            batches.append(Statement(text: remaining, range: currentStart..<sql.endIndex, lineNumber: currentLine))
        }
        return batches
    }

    // MARK: - Statement Splitting Within a Batch

    private static func splitBatch(_ batch: String, batchStart: String.Index, baseLineNumber: Int, in fullSQL: String) -> [Statement] {
        var statements: [Statement] = []
        var currentStart = batch.startIndex
        var stmtStartLine = baseLineNumber
        var currentLine = baseLineNumber
        var i = batch.startIndex
        var blockDepth = 0
        var needsLineUpdate = false

        while i < batch.endIndex {
            let ch = batch[i]

            // Track newlines for accurate line counting
            if ch == "\n" {
                currentLine += 1
                if needsLineUpdate {
                    stmtStartLine = currentLine
                    needsLineUpdate = false
                }
            } else if needsLineUpdate && !ch.isWhitespace {
                stmtStartLine = currentLine
                needsLineUpdate = false
            }

            // Skip string literals
            if ch == "'" {
                let before = i
                i = skipStringLiteral(in: batch, from: i)
                // Count newlines inside the literal
                currentLine += batch[before..<i].filter({ $0 == "\n" }).count
                continue
            }

            // Skip block comments
            if ch == "/" && batch.index(after: i) < batch.endIndex && batch[batch.index(after: i)] == "*" {
                let before = i
                i = skipBlockComment(in: batch, from: i)
                currentLine += batch[before..<i].filter({ $0 == "\n" }).count
                continue
            }

            // Skip line comments
            if ch == "-" && batch.index(after: i) < batch.endIndex && batch[batch.index(after: i)] == "-" {
                let before = i
                i = skipLineComment(in: batch, from: i)
                currentLine += batch[before..<i].filter({ $0 == "\n" }).count
                continue
            }

            // Track BEGIN/END block depth
            if matchesKeyword("BEGIN", in: batch, at: i) {
                blockDepth += 1
                i = batch.index(i, offsetBy: 5, limitedBy: batch.endIndex) ?? batch.endIndex
                continue
            }
            if matchesKeyword("END", in: batch, at: i) {
                blockDepth = max(0, blockDepth - 1)
                i = batch.index(i, offsetBy: 3, limitedBy: batch.endIndex) ?? batch.endIndex
                continue
            }

            // Semicolons split statements only at top level
            if ch == ";" && blockDepth == 0 {
                let stmtText = String(batch[currentStart...i]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !stmtText.isEmpty && stmtText != ";" {
                    let offsetStart = fullSQL.index(batchStart, offsetBy: batch.distance(from: batch.startIndex, to: currentStart))
                    let offsetEnd = fullSQL.index(batchStart, offsetBy: batch.distance(from: batch.startIndex, to: batch.index(after: i)))
                    statements.append(Statement(text: stmtText, range: offsetStart..<offsetEnd, lineNumber: stmtStartLine))
                }
                let nextIdx = batch.index(after: i)
                currentStart = nextIdx
                needsLineUpdate = true
                i = nextIdx
                continue
            }

            i = batch.index(after: i)
        }

        // Remaining text after last semicolon
        if needsLineUpdate {
            // Find the line of the first non-whitespace character in remaining text
            let remaining = batch[currentStart...]
            for c in remaining {
                if c == "\n" { currentLine += 1 }
                else if !c.isWhitespace { stmtStartLine = currentLine; break }
            }
        }
        let remaining = String(batch[currentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !remaining.isEmpty {
            let offsetStart = fullSQL.index(batchStart, offsetBy: batch.distance(from: batch.startIndex, to: currentStart))
            statements.append(Statement(text: remaining, range: offsetStart..<fullSQL.index(batchStart, offsetBy: batch.distance(from: batch.startIndex, to: batch.endIndex)), lineNumber: stmtStartLine))
        }

        return statements
    }

    // MARK: - Skip Helpers

    private static func skipStringLiteral(in sql: String, from start: String.Index) -> String.Index {
        var i = sql.index(after: start)
        while i < sql.endIndex {
            if sql[i] == "'" {
                let next = sql.index(after: i)
                if next < sql.endIndex && sql[next] == "'" {
                    // Escaped single quote
                    i = sql.index(after: next)
                    continue
                }
                return sql.index(after: i)
            }
            i = sql.index(after: i)
        }
        return sql.endIndex
    }

    private static func skipBlockComment(in sql: String, from start: String.Index) -> String.Index {
        var i = sql.index(start, offsetBy: 2, limitedBy: sql.endIndex) ?? sql.endIndex
        var depth = 1
        while i < sql.endIndex && depth > 0 {
            let ch = sql[i]
            let next = sql.index(after: i)
            if ch == "/" && next < sql.endIndex && sql[next] == "*" {
                depth += 1
                i = sql.index(after: next)
            } else if ch == "*" && next < sql.endIndex && sql[next] == "/" {
                depth -= 1
                i = sql.index(after: next)
            } else {
                i = next
            }
        }
        return i
    }

    private static func skipLineComment(in sql: String, from start: String.Index) -> String.Index {
        var i = sql.index(start, offsetBy: 2, limitedBy: sql.endIndex) ?? sql.endIndex
        while i < sql.endIndex && sql[i] != "\n" {
            i = sql.index(after: i)
        }
        if i < sql.endIndex {
            i = sql.index(after: i) // skip newline
        }
        return i
    }

    // MARK: - Keyword Matching

    private static func matchesKeyword(_ keyword: String, in sql: String, at position: String.Index) -> Bool {
        // Must be preceded by a word boundary
        if position > sql.startIndex {
            let prev = sql[sql.index(before: position)]
            if prev.isLetter || prev.isNumber || prev == "_" { return false }
        }

        var kIdx = keyword.startIndex
        var sIdx = position
        while kIdx < keyword.endIndex && sIdx < sql.endIndex {
            if keyword[kIdx].lowercased() != sql[sIdx].lowercased() { return false }
            kIdx = keyword.index(after: kIdx)
            sIdx = sql.index(after: sIdx)
        }
        guard kIdx == keyword.endIndex else { return false }

        // Must be followed by a word boundary
        if sIdx < sql.endIndex {
            let next = sql[sIdx]
            if next.isLetter || next.isNumber || next == "_" { return false }
        }
        return true
    }

    // MARK: - GO Detection

    private static func isLineStart(in sql: String, at position: String.Index) -> Bool {
        if position == sql.startIndex { return true }
        // Walk backward past whitespace (spaces/tabs only)
        var i = sql.index(before: position)
        while i >= sql.startIndex {
            let ch = sql[i]
            if ch == "\n" { return true }
            if ch != " " && ch != "\t" { return false }
            if i == sql.startIndex { return false }
            i = sql.index(before: i)
        }
        return false
    }

    private static func matchesGO(in sql: String, at position: String.Index) -> Bool {
        // Skip leading whitespace on the line
        var i = position
        while i < sql.endIndex && (sql[i] == " " || sql[i] == "\t") {
            i = sql.index(after: i)
        }

        guard i < sql.endIndex else { return false }
        let next1 = i
        guard sql[next1].lowercased() == "g" else { return false }
        let next2 = sql.index(after: next1)
        guard next2 < sql.endIndex && sql[next2].lowercased() == "o" else { return false }
        let afterGO = sql.index(after: next2)

        // GO must be end of line, end of string, or followed by whitespace/newline
        if afterGO >= sql.endIndex { return true }
        let following = sql[afterGO]
        return following == "\n" || following == "\r" || following == " " || following == "\t"
    }

    private static func skipGO(in sql: String, from position: String.Index) -> String.Index {
        var i = position
        // Skip whitespace before GO
        while i < sql.endIndex && (sql[i] == " " || sql[i] == "\t") {
            i = sql.index(after: i)
        }
        // Skip "GO"
        if i < sql.endIndex { i = sql.index(after: i) } // G
        if i < sql.endIndex { i = sql.index(after: i) } // O
        // Skip to end of line
        while i < sql.endIndex && sql[i] != "\n" {
            i = sql.index(after: i)
        }
        if i < sql.endIndex { i = sql.index(after: i) } // skip newline
        return i
    }

    // MARK: - Line Number

    private static func lineNumber(in sql: String, upTo position: String.Index) -> Int {
        sql[sql.startIndex..<position].filter({ $0 == "\n" }).count + 1
    }

    // MARK: - Variable Extraction

    private static func extractVariableNames(from line: String) -> [String] {
        var names: [String] = []
        var i = line.startIndex
        while i < line.endIndex {
            if line[i] == "@" {
                let start = i
                i = line.index(after: i)
                // Allow @@ for system variables — skip those
                if i < line.endIndex && line[i] == "@" {
                    while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_" || line[i] == "@") {
                        i = line.index(after: i)
                    }
                    continue
                }
                while i < line.endIndex && (line[i].isLetter || line[i].isNumber || line[i] == "_") {
                    i = line.index(after: i)
                }
                let name = String(line[start..<i])
                if name.count > 1 { // must be more than just "@"
                    names.append(name)
                }
            } else {
                i = line.index(after: i)
            }
        }
        return names
    }
}
