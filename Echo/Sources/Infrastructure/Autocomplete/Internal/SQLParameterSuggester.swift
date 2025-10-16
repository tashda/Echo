import Foundation

enum SQLParameterSuggester {
    static func parameterSuggestions(for text: String, dialect: SQLDialect) -> [String] {
        let nextIndex = nextParameterIndex(in: text, dialect: dialect)
        switch dialect {
        case .postgresql, .sqlite:
            return ["$\(nextIndex)"]
        case .mysql:
            return ["?"]
        case .microsoftSQL:
            return ["@p\(nextIndex)"]
        }
    }

    private static func nextParameterIndex(in text: String, dialect: SQLDialect) -> Int {
        var highest = 0
        switch dialect {
        case .postgresql, .sqlite:
            let pattern = #"\$(\d+)"#
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                let indexRange = match.range(at: 1)
                if let swiftRange = Range(indexRange, in: text),
                   let value = Int(text[swiftRange]),
                   value > highest {
                    highest = value
                }
            }
        case .mysql:
            // MySQL uses ?, so just reuse count
            let count = text.filter { $0 == "?" }.count
            highest = count
        case .microsoftSQL:
            let pattern = #"@p(\d+)"#
            let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                guard let match, match.numberOfRanges > 1 else { return }
                let indexRange = match.range(at: 1)
                if let swiftRange = Range(indexRange, in: text),
                   let value = Int(text[swiftRange]),
                   value > highest {
                    highest = value
                }
            }
        }
        return highest + 1
    }
}
