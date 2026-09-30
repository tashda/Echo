import Foundation
import PostgresKit
import PostgresWire
import SQLServerKit

/// Where a failed run's error is, marked in the editor (Echo Labs round 21, Postgres: where the
/// error is, accepted: EM5 a squiggle with the message in a bubble on hover, EH3 a Fix button when
/// the error names a column, EC3 cleared by an edit or the next run, IF1 an error inside a routine
/// marks the call. Round 22 ED1: the same for SQL Server, which reports a line, not a position).
nonisolated struct QueryErrorMark: Equatable, Sendable {
    struct Fix: Equatable, Sendable {
        let title: String
        let replacement: String
    }

    /// The marked text in the editor (UTF-16 range).
    let range: NSRange
    /// 1-based editor line of the mark.
    let line: Int
    let message: String
    /// The server's hint, or where inside a routine it failed (`dbo.load_orders, line 12`).
    let detail: String?
    let fix: Fix?
}

/// Turns a failed run's error into a ``QueryErrorMark``.
nonisolated enum QueryErrorMarker {
    /// - Parameters:
    ///   - sentSQL: the SQL that was sent (a SQL Server batch or a PostgreSQL statement).
    ///   - editorText: the editor's text when the run started.
    ///   - runRange: what ran in the editor, to find `sentSQL` in it.
    ///   - columnCandidates: columns of the tables the SQL names, for EH3 on SQL Server.
    static func mark(
        for error: any Error,
        sentSQL: String,
        editorText: String,
        runRange: NSRange?,
        columnCandidates: [String] = []
    ) -> QueryErrorMark? {
        guard let located = locate(sentSQL, in: editorText, runRange: runRange) else { return nil }
        if let details = SQLServerFailure.details(of: error) {
            return sqlServerMark(details.primary, in: located, columnCandidates: columnCandidates)
        }
        if let pointer = PostgresPointer(error) {
            return postgresMark(pointer, in: located)
        }
        return nil
    }

    /// The PostgreSQL mark for a pointer read from the server's error.
    static func mark(postgres pointer: PostgresPointer, sentSQL: String, editorText: String, runRange: NSRange?) -> QueryErrorMark? {
        guard let located = locate(sentSQL, in: editorText, runRange: runRange) else { return nil }
        return postgresMark(pointer, in: located)
    }

    /// The editor line (1-based) that line `line` of the sent SQL is on, for Messages links (LL1).
    static func editorLine(forSentLine line: Int, sentSQL: String, editorText: String, runRange: NSRange?) -> Int? {
        guard let located = locate(sentSQL, in: editorText, runRange: runRange) else { return nil }
        let lineInTrimmed = line - located.leadingNewlines
        guard lineInTrimmed >= 1, let range = lineRange(lineInTrimmed, in: located.trimmed) else { return nil }
        return editorLineNumber(at: located.base + range.location, in: editorText)
    }

    // MARK: - Finding the sent SQL in the editor

    struct Located {
        /// The sent SQL without surrounding whitespace, as found in the editor.
        let trimmed: NSString
        /// UTF-16 offset of `trimmed` in the editor.
        let base: Int
        /// Lines and characters of the sent SQL before `trimmed` (servers count them).
        let leadingNewlines: Int
        let leadingCharacters: Int
        let editorText: String
    }

    /// Finds the sent SQL in the editor. Lines Echo added in front (`USE [db];`,
    /// `SET STATISTICS …`) are not in the editor: they are skipped and counted as leading lines.
    static func locate(_ sentSQL: String, in editorText: String, runRange: NSRange?) -> Located? {
        let text = editorText as NSString
        let whole = NSRange(location: 0, length: text.length)
        var remaining = Substring(sentSQL)
        var skippedLines = 0
        var skippedCharacters = 0
        for _ in 0...4 {
            let leading = remaining.prefix { $0.isWhitespace || $0.isNewline }
            let trimmed = remaining.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            var found = NSRange(location: NSNotFound, length: 0)
            if let runRange {
                found = text.range(of: trimmed, options: [], range: NSIntersectionRange(runRange, whole))
            }
            if found.location == NSNotFound { found = text.range(of: trimmed, options: [], range: whole) }
            if found.location != NSNotFound {
                return Located(
                    trimmed: trimmed as NSString,
                    base: found.location,
                    leadingNewlines: skippedLines + leading.filter(\.isNewline).count,
                    leadingCharacters: skippedCharacters + leading.unicodeScalars.count,
                    editorText: editorText
                )
            }
            // Drop the first line and try again.
            guard let newline = remaining.firstIndex(where: \.isNewline) else { return nil }
            let dropped = remaining[...newline]
            skippedLines += 1
            skippedCharacters += dropped.unicodeScalars.count
            remaining = remaining[remaining.index(after: newline)...]
        }
        return nil
    }

    // MARK: - SQL Server

    private static func sqlServerMark(_ primary: SQLServerStreamMessage, in located: Located, columnCandidates: [String]) -> QueryErrorMark? {
        let message = primary.message
        let procedure = primary.procedureName
        let text = located.trimmed

        // IF1: an error inside a procedure marks the EXEC of it; the bubble names the procedure's line.
        if !procedure.isEmpty {
            guard let call = execCall(of: procedure, in: text as String) else { return nil }
            return make(range: NSRange(location: located.base + call.location, length: call.length), in: located,
                        message: message, detail: "\(procedure), line \(primary.lineNumber)", fix: nil)
        }

        let lineInTrimmed = Int(primary.lineNumber) - located.leadingNewlines
        guard lineInTrimmed >= 1, let line = lineRange(lineInTrimmed, in: text) else { return nil }
        // Narrow to the object the message names, e.g. 207 Invalid column name 'x'.
        var range = trimmedLine(line, in: text)
        var fix: QueryErrorMark.Fix?
        if let name = quotedName(in: message) {
            let lineText = text.substring(with: line) as NSString
            let lastPart = name.split(separator: ".").last.map(String.init) ?? name
            var found = lineText.range(of: name, options: .caseInsensitive)
            if found.location == NSNotFound { found = lineText.range(of: lastPart, options: .caseInsensitive) }
            if found.location != NSNotFound {
                range = NSRange(location: line.location + found.location, length: found.length)
            }
            // EH3: 207 Invalid column name → the closest column of the tables the statement names.
            if primary.number == 207, let closest = closestName(to: lastPart, among: columnCandidates) {
                fix = .init(title: "Use \(closest)", replacement: closest)
            }
        }
        return make(range: NSRange(location: located.base + range.location, length: range.length), in: located,
                    message: message, detail: nil, fix: fix)
    }

    /// The `EXEC dbo.proc` call in the batch, found by the procedure's last name part.
    static func execCall(of procedure: String, in sql: String) -> NSRange? {
        let name = procedure.split(separator: ".").last.map(String.init) ?? procedure
        let bare = name.trimmingCharacters(in: CharacterSet(charactersIn: "[]\""))
        let escaped = NSRegularExpression.escapedPattern(for: bare)
        let pattern = #"(?i)\bexec(?:ute)?\s+(?:@\w+\s*=\s*)?(?:(?:\[[^\]]+\]|[\w#]+)\.){0,2}\[?"# + escaped + #"\]?(?![\w#])"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: sql, range: NSRange(location: 0, length: (sql as NSString).length)) else { return nil }
        return match.range
    }

    static func quotedName(in message: String) -> String? {
        guard let match = message.firstMatch(of: /'([^']+)'/) else { return nil }
        return String(match.1)
    }

    // MARK: - PostgreSQL

    struct PostgresPointer {
        let message: String
        /// 1-based character position in the statement.
        let position: Int?
        let hint: String?
        /// "PL/pgSQL function load_orders() line 12 at RAISE"
        let context: String?

        init(message: String, position: Int?, hint: String?, context: String?) {
            self.message = message
            self.position = position
            self.hint = hint
            self.context = context
        }

        init?(_ error: any Error) {
            var candidate: any Error = error
            if let database = error as? DatabaseError, case .queryError(_, let underlying?) = database {
                candidate = underlying
            }
            if let kit = candidate as? PostgresKit.PostgresError {
                message = kit.serverMessage ?? kit.message
                position = kit.position
                hint = kit.hint
                context = nil
            } else if let psql = candidate as? PSQLError, let info = psql.serverInfo {
                message = info[.message] ?? psql.localizedDescription
                position = info[.position].flatMap { Int($0) }
                hint = info[.hint]
                context = info[.locationContext]
            } else {
                return nil
            }
            guard position != nil || context != nil else { return nil }
        }
    }

    private static func postgresMark(_ pointer: PostgresPointer, in located: Located) -> QueryErrorMark? {
        let text = located.trimmed as String
        // IF1: inside a function, mark the call and name the function's line.
        if pointer.position == nil, let context = pointer.context,
           let match = context.firstMatch(of: /function (\S+?)\(.*?\) line (\d+)/) {
            let function = String(match.1)
            let name = function.split(separator: ".").last.map(String.init) ?? function
            let found = (text as NSString).range(of: name + "(", options: .caseInsensitive)
            guard found.location != NSNotFound else { return nil }
            let range = NSRange(location: found.location, length: (name as NSString).length)
            return make(range: NSRange(location: located.base + range.location, length: range.length), in: located,
                        message: pointer.message, detail: "\(function), line \(match.2)", fix: nil)
        }
        guard let position = pointer.position else { return nil }
        let scalarOffset = position - 1 - located.leadingCharacters
        let scalars = text.unicodeScalars
        guard scalarOffset >= 0, scalarOffset < scalars.count else { return nil }
        let index = scalars.index(scalars.startIndex, offsetBy: scalarOffset)
        let utf16Offset = text.utf16.distance(from: text.utf16.startIndex, to: index.samePosition(in: text.utf16) ?? text.utf16.startIndex)
        let word = wordRange(at: utf16Offset, in: located.trimmed)
        let fix = pointer.hint.flatMap { postgresFix(hint: $0, markedWord: located.trimmed.substring(with: word)) }
        return make(range: NSRange(location: located.base + word.location, length: word.length), in: located,
                    message: pointer.message, detail: pointer.hint, fix: fix)
    }

    /// EH3: `Perhaps you meant to reference the column "orders.status".` → Use orders.status.
    static func postgresFix(hint: String, markedWord: String) -> QueryErrorMark.Fix? {
        guard let match = hint.firstMatch(of: /column "(?:([^".]+)\.)?([^".]+)"/) else { return nil }
        let column = String(match.2)
        let qualified = match.1.map { "\($0).\(column)" } ?? column
        let parts = markedWord.split(separator: ".")
        let replacement = parts.count > 1 ? parts.dropLast().joined(separator: ".") + "." + column : column
        return .init(title: "Use \(qualified)", replacement: replacement)
    }

    // MARK: - Text helpers

    private static func make(range: NSRange, in located: Located, message: String, detail: String?, fix: QueryErrorMark.Fix?) -> QueryErrorMark {
        QueryErrorMark(
            range: range,
            line: editorLineNumber(at: range.location, in: located.editorText),
            message: message,
            detail: detail?.isEmpty == true ? nil : detail,
            fix: fix
        )
    }

    /// The range of 1-based line `line` in `text`, without its line break.
    static func lineRange(_ line: Int, in text: NSString) -> NSRange? {
        var location = 0
        for _ in 1..<line {
            let next = text.range(of: "\n", options: [], range: NSRange(location: location, length: text.length - location))
            guard next.location != NSNotFound else { return nil }
            location = next.location + 1
        }
        guard location <= text.length else { return nil }
        let end = text.range(of: "\n", options: [], range: NSRange(location: location, length: text.length - location))
        let length = (end.location == NSNotFound ? text.length : end.location) - location
        return NSRange(location: location, length: length)
    }

    /// The line without leading and trailing whitespace (the whole line when it is blank).
    private static func trimmedLine(_ line: NSRange, in text: NSString) -> NSRange {
        let content = text.substring(with: line)
        let leading = content.prefix { $0.isWhitespace }.utf16.count
        let trailing = content.reversed().prefix { $0.isWhitespace }.map { String($0) }.joined().utf16.count
        let length = line.length - leading - trailing
        return length > 0 ? NSRange(location: line.location + leading, length: length) : line
    }

    /// The identifier at `offset` (letters, digits, `_`, `$`, `.` and double quotes).
    static func wordRange(at offset: Int, in text: NSString) -> NSRange {
        func isWord(_ unit: unichar) -> Bool {
            guard let scalar = Unicode.Scalar(unit) else { return false }
            return CharacterSet.alphanumerics.contains(scalar) || "_$.\"".unicodeScalars.contains(scalar)
        }
        var start = min(offset, text.length)
        var end = start
        while start > 0, isWord(text.character(at: start - 1)) { start -= 1 }
        while end < text.length, isWord(text.character(at: end)) { end += 1 }
        return end > start ? NSRange(location: start, length: end - start) : NSRange(location: min(offset, max(text.length - 1, 0)), length: min(1, text.length))
    }

    static func editorLineNumber(at location: Int, in text: String) -> Int {
        var line = 1
        for (index, unit) in text.utf16.enumerated() {
            if index >= location { break }
            if unit == 0x0A { line += 1 }
        }
        return line
    }

    /// The candidate closest to `name` (case-insensitive edit distance), when it is close enough
    /// to be the same word mistyped.
    static func closestName(to name: String, among candidates: [String]) -> String? {
        let target = name.lowercased()
        let limit = max(1, min(3, target.count / 3))
        var best: (name: String, distance: Int)?
        for candidate in Set(candidates) {
            let distance = editDistance(target, candidate.lowercased())
            guard distance > 0, distance <= limit else { continue }
            if best == nil || distance < best!.distance || (distance == best!.distance && candidate < best!.name) {
                best = (candidate, distance)
            }
        }
        return best?.name
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }
        var previous = Array(0...b.count)
        var current = [Int](repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                current[j] = min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }
}
