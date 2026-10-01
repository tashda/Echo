import Foundation

/// The statement a message belongs to, as Messages heads its group (round 41.4, ML1): the line
/// it starts on in the editor and its first line of text.
struct QueryMessageStatement: Hashable {
    let line: Int
    let text: String

    /// The heading for `range` of `sql` (the whole text when nil): its first line with text, and
    /// that line's number. Nil when the range holds only whitespace.
    static func heading(for sql: String, range: NSRange? = nil) -> QueryMessageStatement? {
        let text = sql as NSString
        let full = NSRange(location: 0, length: text.length)
        let bounded = range.map { NSIntersectionRange($0, full) } ?? full
        guard bounded.length > 0 || range == nil else { return nil }
        var lineNumber = text.substring(to: bounded.location).components(separatedBy: "\n").count
        for line in text.substring(with: bounded).components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return QueryMessageStatement(line: lineNumber, text: trimmed) }
            lineNumber += 1
        }
        return nil
    }
}

/// Messages in a row that belong to the same statement, under one heading (round 41.4, ML1).
struct QueryMessageGroup: Identifiable {
    let statement: QueryMessageStatement?
    let messages: [QueryExecutionMessage]
    var id: UUID { messages.first?.id ?? UUID() }

    /// Consecutive messages with the same statement form a group; messages without one form
    /// groups without a heading.
    static func groups(from messages: [QueryExecutionMessage]) -> [QueryMessageGroup] {
        var groups: [QueryMessageGroup] = []
        for message in messages {
            if let last = groups.last, last.statement == message.statement {
                groups[groups.count - 1] = QueryMessageGroup(statement: last.statement, messages: last.messages + [message])
            } else {
                groups.append(QueryMessageGroup(statement: message.statement, messages: [message]))
            }
        }
        return groups
    }
}
