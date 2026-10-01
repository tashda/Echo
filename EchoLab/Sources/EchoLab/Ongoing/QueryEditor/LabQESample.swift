import Foundation

/// Round 28: the script every editor specimen shows, two statements, and the places on it the
/// scenes point at (the caret, a selection, find matches, an error). Lines count from 1, columns
/// from 0, like Echo's gutter and NSString.
enum LabQESample {
    static func lines(misspelled: Bool = false) -> [String] {
        [
            "-- Orders that haven't shipped",
            "SELECT o.order_id, c.name, o.total",
            "FROM orders AS o",
            misspelled ? "JOIN custmers AS c ON c.customer_id = o.customer_id" : "JOIN customers AS c ON c.customer_id = o.customer_id",
            "WHERE o.shipped_at IS NULL",
            "  AND o.total >= 100",
            "  AND o.status <> 'cancelled'",
            "ORDER BY o.total DESC;",
            "",
            "UPDATE orders",
            "SET status = 'late'",
            "WHERE shipped_at IS NULL;",
        ]
    }

    /// The script's statements, by line.
    static let statements: [ClosedRange<Int>] = [1...8, 10...12]

    static let caret = LabQEPosition(line: 5, column: 12)
    /// Every `shipped_at`: the word at the caret, which Echo highlights wherever it appears.
    static let caretWord: [LabQESpan] = [.init(line: 5, start: 8, end: 18), .init(line: 12, start: 6, end: 16)]
    /// A selection from `o.total >= 100` to the end of the next line.
    static let selection = (from: LabQEPosition(line: 6, column: 6), to: LabQEPosition(line: 7, column: 29))
    /// Find "orders": the current match first.
    static let findMatches: [LabQESpan] = [.init(line: 3, start: 5, end: 11), .init(line: 10, start: 7, end: 13)]
    /// The misspelled table on line 4.
    static let error = LabQESpan(line: 4, start: 5, end: 13)
    static let errorMessage = "Unknown table 'custmers'"
    static let serverErrorMessage = "Invalid object name 'custmers'."
    /// The bracket pair Echo would match with the caret after `(`, in the bracket scene.
    static let bracketPair: [LabQESpan] = []

    static let keywords: Set<String> = ["SELECT", "FROM", "JOIN", "AS", "ON", "WHERE", "IS", "NULL", "AND", "ORDER", "BY",
                                        "DESC", "UPDATE", "SET"]

    /// A line split into coloured runs, the way Echo's highlighter colours it.
    static func tokens(_ line: String) -> [LabQEToken] {
        var tokens: [LabQEToken] = []
        let chars = Array(line)
        var index = 0
        func take(_ kind: LabQEToken.Kind, while keep: (Character) -> Bool) {
            let start = index
            while index < chars.count, keep(chars[index]) { index += 1 }
            tokens.append(.init(text: String(chars[start..<index]), kind: kind))
        }
        while index < chars.count {
            let char = chars[index]
            if char == "-", index + 1 < chars.count, chars[index + 1] == "-" {
                tokens.append(.init(text: String(chars[index...]), kind: .comment))
                break
            } else if char == "'" {
                let start = index
                index += 1
                while index < chars.count, chars[index] != "'" { index += 1 }
                index = min(index + 1, chars.count)
                tokens.append(.init(text: String(chars[start..<index]), kind: .string))
            } else if char.isNumber {
                take(.number) { $0.isNumber }
            } else if char.isLetter || char == "_" {
                let start = index
                while index < chars.count, chars[index].isLetter || chars[index].isNumber || chars[index] == "_" { index += 1 }
                let word = String(chars[start..<index])
                let kind: LabQEToken.Kind = keywords.contains(word.uppercased()) ? .keyword
                    : (index < chars.count && chars[index] == "(") ? .function : .plain
                tokens.append(.init(text: word, kind: kind))
            } else if char == " " {
                take(.plain) { $0 == " " }
            } else {
                take(.symbol) { !$0.isLetter && !$0.isNumber && $0 != " " && $0 != "'" && $0 != "_" }
            }
        }
        return tokens
    }
}

struct LabQEToken {
    enum Kind { case keyword, string, number, comment, function, symbol, plain }
    let text: String
    let kind: Kind
}

struct LabQEPosition: Equatable {
    let line: Int
    let column: Int
}

/// Columns `start..<end` on one line.
struct LabQESpan: Equatable {
    let line: Int
    let start: Int
    let end: Int
}
