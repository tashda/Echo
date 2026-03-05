#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    static let keywords: [String] = [
        "SELECT", "INSERT", "UPDATE", "DELETE", "CREATE", "ALTER", "DROP", "TRUNCATE", "REPLACE", "MERGE", "GRANT", "REVOKE", "ANALYZE",
        "EXPLAIN", "VACUUM", "FROM", "WHERE", "JOIN", "INNER", "LEFT", "RIGHT", "FULL", "OUTER", "CROSS", "ON", "GROUP", "BY", "HAVING",
        "ORDER", "LIMIT", "OFFSET", "FETCH", "UNION", "ALL", "DISTINCT", "INTO", "VALUES", "SET", "RETURNING", "WITH", "AS", "AND", "OR",
        "NOT", "NULL", "IS", "IN", "BETWEEN", "EXISTS", "LIKE", "ILIKE", "SIMILAR", "CASE", "WHEN", "THEN", "ELSE", "END", "USING", "OVER",
        "PARTITION", "FILTER", "WINDOW", "DESC", "ASC", "TOP", "PRIMARY", "FOREIGN", "KEY", "CONSTRAINT", "DEFAULT", "CHECK"
    ]

    static let singleLineCommentRegex = try! NSRegularExpression(pattern: #"--[^\n]*"#, options: [])
    static let blockCommentRegex = try! NSRegularExpression(pattern: #"\/\*[\s\S]*?\*\/"#, options: [.dotMatchesLineSeparators])
    static let singleQuotedStringRegex = try! NSRegularExpression(pattern: #"'([^']|'')*'"#, options: [])
    static let numberRegex = try! NSRegularExpression(pattern: #"\b\d+(?:\.\d+)?\b"#, options: [])
    static let operatorRegex = try! NSRegularExpression(pattern: #"(?<![A-Za-z0-9_])(?:<>|!=|>=|<=|::|\*\*|[-+*/=%<>!]+)"#, options: [])
    static let functionRegex = try! NSRegularExpression(pattern: #"\b([A-Z_][A-Z0-9_]*)\s*(?=\()"#, options: [.caseInsensitive])
    static let keywordRegex: NSRegularExpression = {
        let pattern = #"\b(?:"# + keywords.joined(separator: "|") + #")\b"#
        return try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }()
    static let identifierRegex = try! NSRegularExpression(pattern: #"\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*\b"#, options: [])
    static let allKeywords: Set<String> = Set(keywords.map { $0.lowercased() })

    static var objectContextKeywords: Set<String> { SQLContextParser.objectContextKeywords }
    static var columnContextKeywords: Set<String> { SQLContextParser.columnContextKeywords }
    static var aliasTerminatingKeywords: Set<String> {
        ["WHERE", "INNER", "LEFT", "RIGHT", "ON", "JOIN", "SET", "ORDER", "GROUP", "HAVING", "LIMIT"]
    }

    static let identifierDelimiterCharacterSet = CharacterSet(charactersIn: "\"[]`")
    static let completionTokenCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "$_.")
        set.insert(charactersIn: "*")
        return set
    }()

    static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        let startSet = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let bodySet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard startSet.contains(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy { bodySet.contains($0) }
    }
}
#endif
