import Foundation

/// Splits a SQL Server script into individual batches at GO boundaries.
///
/// GO is a client-side batch separator — it is never sent to the server.
/// This splitter handles all SSMS-compatible GO semantics:
/// - Case-insensitive (`GO`, `go`, `Go`)
/// - GO must be on its own line (only whitespace before, optional count/comment after)
/// - GO inside string literals, bracket identifiers, and comments is ignored
/// - `GO N` repeats the batch N times
/// - `GO;` is NOT treated as a separator
nonisolated struct MSSQLBatchSplitter {

    struct Batch: Sendable {
        /// The SQL text of this batch (without GO).
        let text: String
        /// Number of times to execute (from `GO N`). Default is 1.
        let repeatCount: Int
        /// 0-based line number in the original script where this batch starts.
        let startLine: Int
    }

    struct SplitResult: Sendable {
        let batches: [Batch]
    }

    // MARK: - Public API

    static func split(_ sql: String) -> SplitResult {
        let lines = sql.components(separatedBy: "\n")
        var batches: [Batch] = []
        var currentBatchLines: [String] = []
        var batchStartLine = 0

        // Track parser state for multi-line constructs
        var inBlockComment = 0  // nesting depth
        var inSingleQuoteString = false
        var inBracketIdentifier = false

        for (lineIndex, line) in lines.enumerated() {
            // If we're not inside a string, bracket, or block comment,
            // check if this line is a GO separator
            if !inSingleQuoteString && !inBracketIdentifier && inBlockComment == 0 {
                if let goMatch = matchGOLine(line) {
                    // Flush current batch
                    let batchText = currentBatchLines.joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !batchText.isEmpty {
                        batches.append(Batch(
                            text: batchText,
                            repeatCount: max(1, goMatch.count),
                            startLine: batchStartLine
                        ))
                    }
                    currentBatchLines.removeAll()
                    batchStartLine = lineIndex + 1
                    continue
                }
            }

            currentBatchLines.append(line)

            // Update parser state by scanning characters in this line
            updateParserState(
                line: line,
                inBlockComment: &inBlockComment,
                inSingleQuoteString: &inSingleQuoteString,
                inBracketIdentifier: &inBracketIdentifier
            )
        }

        // Flush final batch
        let batchText = currentBatchLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !batchText.isEmpty {
            batches.append(Batch(
                text: batchText,
                repeatCount: 1,
                startLine: batchStartLine
            ))
        }

        return SplitResult(batches: batches)
    }

    // MARK: - GO Line Detection

    private struct GOMatch {
        let count: Int
    }

    /// Checks if a line is a GO separator.
    ///
    /// Valid GO lines:
    /// - `GO` (with optional leading/trailing whitespace)
    /// - `GO 5` (with repeat count)
    /// - `GO -- comment` (with trailing comment)
    /// - `GO 5 -- comment`
    ///
    /// Invalid (NOT treated as GO):
    /// - `GO;` (semicolon after GO)
    /// - `SELECT GO` (GO not at line start)
    /// - `GOTO label` (GO is prefix of another keyword)
    private static func matchGOLine(_ line: String) -> GOMatch? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Must start with GO (case-insensitive)
        guard trimmed.count >= 2 else { return nil }
        let prefix = trimmed.prefix(2)
        guard prefix.caseInsensitiveCompare("GO") == .orderedSame else { return nil }

        // If exactly "GO", it's a match
        if trimmed.count == 2 {
            return GOMatch(count: 1)
        }

        // Character after GO must be whitespace or start of comment
        let afterGO = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)]
        guard afterGO == " " || afterGO == "\t" || afterGO == "-" else {
            // Catches GO; (semicolon), GOTO, GONE, etc.
            return nil
        }

        // If it's a comment immediately after GO (e.g., "GO--comment")
        if afterGO == "-" {
            let rest = trimmed.dropFirst(2)
            if rest.hasPrefix("--") {
                return GOMatch(count: 1)
            }
            return nil
        }

        // Parse remainder: optional count, optional comment
        let remainder = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)

        // Empty remainder after whitespace
        if remainder.isEmpty {
            return GOMatch(count: 1)
        }

        // Check for trailing comment only
        if remainder.hasPrefix("--") {
            return GOMatch(count: 1)
        }

        // Check for semicolon — GO; is invalid
        if remainder.hasPrefix(";") {
            return nil
        }

        // Try to parse a count
        var countStr = ""
        var idx = remainder.startIndex
        while idx < remainder.endIndex && remainder[idx].isNumber {
            countStr.append(remainder[idx])
            idx = remainder.index(after: idx)
        }

        guard !countStr.isEmpty, let count = Int(countStr) else {
            return nil
        }

        // After the count, only whitespace or comment is allowed
        let afterCount = remainder[idx...].trimmingCharacters(in: .whitespaces)
        if afterCount.isEmpty || afterCount.hasPrefix("--") {
            return GOMatch(count: count)
        }

        // Anything else (e.g., GO 5 SELECT) is not a valid GO line
        return nil
    }

    // MARK: - Parser State Tracking

    /// Scans a line to update the parser state for strings, brackets, and block comments.
    ///
    /// This tracks multi-line constructs so GO detection knows when it's inside
    /// a string literal, bracket identifier, or block comment.
    private static func updateParserState(
        line: String,
        inBlockComment: inout Int,
        inSingleQuoteString: inout Bool,
        inBracketIdentifier: inout Bool
    ) {
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]
            let nextIndex = line.index(after: i)
            let nextChar: Character? = nextIndex < line.endIndex ? line[nextIndex] : nil

            if inBlockComment > 0 {
                // Inside block comment: look for */ or nested /*
                if char == "*" && nextChar == "/" {
                    inBlockComment -= 1
                    i = line.index(after: nextIndex)
                    continue
                } else if char == "/" && nextChar == "*" {
                    inBlockComment += 1
                    i = line.index(after: nextIndex)
                    continue
                }
            } else if inSingleQuoteString {
                // Inside string: look for closing quote ('' is escape)
                if char == "'" {
                    if nextChar == "'" {
                        // Escaped quote — skip both
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        inSingleQuoteString = false
                    }
                }
            } else if inBracketIdentifier {
                // Inside bracket identifier: look for closing ]
                if char == "]" {
                    if nextChar == "]" {
                        // Escaped bracket — skip both
                        i = line.index(after: nextIndex)
                        continue
                    } else {
                        inBracketIdentifier = false
                    }
                }
            } else {
                // Normal context — check for opening constructs
                if char == "'" {
                    inSingleQuoteString = true
                } else if char == "[" {
                    inBracketIdentifier = true
                } else if char == "/" && nextChar == "*" {
                    inBlockComment += 1
                    i = line.index(after: nextIndex)
                    continue
                } else if char == "-" && nextChar == "-" {
                    // Line comment — rest of line is comment, stop scanning
                    return
                }
            }

            i = nextIndex
        }
    }
}
