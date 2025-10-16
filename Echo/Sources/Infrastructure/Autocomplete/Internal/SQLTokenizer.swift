import Foundation

struct SQLToken {
    enum Kind {
        case keyword
        case identifier
        case quotedIdentifier
        case stringLiteral
        case number
        case punctuation
        case operatorSymbol
        case parameter
        case whitespace
        case comment
    }

    let kind: Kind
    let text: String
    let range: NSRange

    var lowercased: String {
        text.lowercased()
    }
}

enum SQLTokenizer {
    static func tokenize(_ text: NSString) -> [SQLToken] {
        var tokens: [SQLToken] = []
        var index = 0
        let length = text.length

        while index < length {
            let scalar = self.scalar(at: index, in: text)

            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                let start = index
                index += 1
                while index < length,
                      CharacterSet.whitespacesAndNewlines.contains(self.scalar(at: index, in: text)) {
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .whitespace,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if scalar == "-" && index + 1 < length && self.scalar(at: index + 1, in: text) == "-" {
                let start = index
                index += 2
                while index < length {
                    let char = text.character(at: index)
                    if char == 10 || char == 13 {
                        break
                    }
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .comment,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if scalar == "/" && index + 1 < length && self.scalar(at: index + 1, in: text) == "*" {
                let start = index
                index += 2
                while index + 1 < length {
                    if self.scalar(at: index, in: text) == "*" && self.scalar(at: index + 1, in: text) == "/" {
                        index += 2
                        break
                    }
                    index += 1
                }
                index = min(index, length)
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .comment,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if scalar == "'" || scalar == "\"" {
                let closing = scalar
                let start = index
                index += 1
                while index < length {
                    let current = self.scalar(at: index, in: text)
                    if current == closing {
                        if index + 1 < length, self.scalar(at: index + 1, in: text) == closing {
                            index += 2
                            continue
                        }
                        index += 1
                        break
                    }
                    index += 1
                }
                index = min(index, length)
                let range = NSRange(location: start, length: index - start)
                let kind: SQLToken.Kind = closing == "'" ? .stringLiteral : .quotedIdentifier
                tokens.append(SQLToken(kind: kind,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if scalar == "`" || scalar == "[" {
                let closing: UnicodeScalar = scalar == "`" ? "`" : "]"
                let start = index
                index += 1
                while index < length {
                    let current = self.scalar(at: index, in: text)
                    if current == closing {
                        index += 1
                        break
                    }
                    index += 1
                }
                index = min(index, length)
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .quotedIdentifier,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if CharacterSet.decimalDigits.contains(scalar) {
                let start = index
                index += 1
                while index < length,
                      CharacterSet.decimalDigits.contains(self.scalar(at: index, in: text)) {
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .number,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if isIdentifierStart(scalar: scalar) {
                let start = index
                index += 1
                while index < length,
                      isIdentifierContinue(scalar: self.scalar(at: index, in: text)) {
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                let value = text.substring(with: range)
                let kind: SQLToken.Kind = keywordSet.contains(value.lowercased()) ? .keyword : .identifier
                tokens.append(SQLToken(kind: kind, text: value, range: range))
                continue
            }

            if scalar == ":" || scalar == "@" || scalar == "$" {
                let start = index
                index += 1
                while index < length,
                      isIdentifierContinue(scalar: self.scalar(at: index, in: text)) {
                    index += 1
                }
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .parameter,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            if operatorScalars.contains(scalar) {
                let start = index
                index += 1
                if index < length {
                    let next = self.scalar(at: index, in: text)
                    if isCompoundOperator(lhs: scalar, rhs: next) {
                        index += 1
                    }
                }
                let range = NSRange(location: start, length: index - start)
                tokens.append(SQLToken(kind: .operatorSymbol,
                                       text: text.substring(with: range),
                                       range: range))
                continue
            }

            let range = NSRange(location: index, length: 1)
            tokens.append(SQLToken(kind: .punctuation,
                                   text: text.substring(with: range),
                                   range: range))
            index += 1
        }

        return tokens
    }

    private static func isIdentifierStart(scalar: UnicodeScalar) -> Bool {
        CharacterSet.letters.contains(scalar) || scalar == "_"
    }

    private static func isIdentifierContinue(scalar: UnicodeScalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) || scalar == "_" || scalar == "$"
    }

    private static let keywordSet: Set<String> = [
        "select", "from", "where", "group", "by", "order", "having", "limit", "offset",
        "insert", "into", "values", "update", "set", "delete", "join", "inner", "left",
        "right", "full", "outer", "cross", "on", "and", "or", "with", "as", "returning",
        "union", "intersect", "except", "distinct", "exists", "over", "partition",
        "case", "when", "then", "else", "end", "using", "top"
    ]

    private static let operatorScalars: Set<UnicodeScalar> = [
        "+", "-", "*", "/", "%", "=", "<", ">", "!", "|", "&", "^", "~"
    ]

    private static func scalar(at index: Int, in text: NSString) -> UnicodeScalar {
        UnicodeScalar(text.character(at: index))!
    }

    private static func isCompoundOperator(lhs: UnicodeScalar, rhs: UnicodeScalar) -> Bool {
        switch (lhs, rhs) {
        case ("<", ">"), ("<", "="), (">", "="), ("!", "="), ("|", "|"), ("&", "&"):
            return true
        default:
            return false
        }
    }
}
