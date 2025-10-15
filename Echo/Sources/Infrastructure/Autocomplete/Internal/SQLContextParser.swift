import Foundation

struct SQLContext {
    struct TableReference: Hashable {
        let schema: String?
        let name: String
        let alias: String?
        let matchLocation: Int

        func matches(schema otherSchema: String?, name otherName: String) -> Bool {
            guard name.caseInsensitiveCompare(otherName) == .orderedSame else { return false }
            guard let schema else { return true }
            guard let otherSchema else { return false }
            return schema.caseInsensitiveCompare(otherSchema) == .orderedSame
        }

        func isEquivalent(to other: SQLContext.TableReference) -> Bool {
            guard matches(schema: other.schema, name: other.name) else { return false }
            let lhsAlias = alias?.lowercased()
            let rhsAlias = other.alias?.lowercased()
            return lhsAlias == rhsAlias
        }

        static func == (lhs: SQLContext.TableReference, rhs: SQLContext.TableReference) -> Bool {
            lhs.isEquivalent(to: rhs)
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(schema?.lowercased())
            hasher.combine(name.lowercased())
            hasher.combine(alias?.lowercased())
        }
    }

    let caretLocation: Int
    let currentToken: String
    let precedingKeyword: String?
    let pathComponents: [String]
    let tablesInScope: [TableReference]
    let focusTable: TableReference?
}

final class SQLContextParser {
    private struct TableMatch {
        let schema: String?
        let name: String
        let alias: String?
        let range: NSRange
    }

    private let text: String
    private let caretLocation: Int
    private let dialect: SQLDialect
    private let catalog: SQLDatabaseCatalog

    init(text: String, caretLocation: Int, dialect: SQLDialect, catalog: SQLDatabaseCatalog) {
        self.text = text
        self.caretLocation = caretLocation
        self.dialect = dialect
        self.catalog = catalog
    }

    func parse() -> SQLContext {
        let trimmedLocation = max(0, min(caretLocation, text.count))
        let nsText = text as NSString
        let tokenRange = tokenRange(at: trimmedLocation, in: nsText)
        let token = tokenRange.length > 0 ? nsText.substring(with: tokenRange) : ""

        let components = token.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let pathComponents = components.dropLast().filter { !$0.isEmpty }

        let precedingKeyword = previousKeyword(before: tokenRange.location, in: nsText)
        let tableMatches = parseTableMatches()
        let tables = deduplicatedReferences(from: tableMatches)
        let focusTable = inferFocusTable(matches: tableMatches, caretLocation: trimmedLocation)

        return SQLContext(caretLocation: trimmedLocation,
                          currentToken: token,
                          precedingKeyword: precedingKeyword,
                          pathComponents: Array(pathComponents),
                          tablesInScope: tables,
                          focusTable: focusTable)
    }

    private func tokenRange(at caretLocation: Int, in text: NSString) -> NSRange {
        var start = caretLocation
        while start > 0 {
            let character = text.character(at: start - 1)
            if SQLContextParser.completionTokenCharacterSet.contains(UnicodeScalar(character)!) {
                start -= 1
            } else {
                break
            }
        }
        return NSRange(location: start, length: caretLocation - start)
    }

    private func previousKeyword(before location: Int, in text: NSString) -> String? {
        guard location > 0 else { return nil }
        let range = NSRange(location: 0, length: location)
        let substring = text.substring(with: range)
        let trimmed = substring.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.components(separatedBy: SQLContextParser.nonWordCharacterSet)
        guard let keyword = components.last(where: { !$0.isEmpty }) else { return nil }
        return keyword.lowercased()
    }

    private func parseTableMatches() -> [TableMatch] {
        guard !text.isEmpty else { return [] }

        // include quoted identifiers and optional alias definitions
        let pattern = "(?ix)\\b(from|join|update|into)\\s+([A-Za-z0-9_.\\\"`\\[\\]]+)(?:\\s+(?:AS\\s+)?([A-Za-z0-9_]+))?"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var matches: [TableMatch] = []

        regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let identifierRange = match.range(at: 2)
            guard let identifierSwift = Range(identifierRange, in: text) else { return }
            let rawIdentifier = String(text[identifierSwift])
            let normalized = SQLContextParser.normalizeIdentifier(rawIdentifier)
            guard !normalized.isEmpty else { return }

            let aliasRange = match.range(at: 3)
            var alias: String?
            if aliasRange.location != NSNotFound,
               let aliasSwift = Range(aliasRange, in: text) {
                let candidate = SQLContextParser.normalizeIdentifier(String(text[aliasSwift]))
                if !candidate.isEmpty,
                   SQLContextParser.isValidIdentifier(candidate),
                   !SQLContextParser.aliasTerminatingKeywords.contains(candidate.uppercased()) {
                    alias = candidate
                }
            }

            let components = normalized.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
            guard let name = components.last else { return }
            let schema = components.dropLast().last
            matches.append(TableMatch(schema: schema,
                                       name: name,
                                       alias: alias,
                                       range: match.range))
        }

        return matches
    }

    private func deduplicatedReferences(from matches: [TableMatch]) -> [SQLContext.TableReference] {
        var unique: [SQLContext.TableReference] = []
        for match in matches {
            let reference = SQLContext.TableReference(schema: match.schema,
                                                      name: match.name,
                                                      alias: match.alias,
                                                      matchLocation: match.range.location)
            if !unique.contains(where: { $0.isEquivalent(to: reference) }) {
                unique.append(reference)
            }
        }
        return unique
    }

    private func inferFocusTable(matches: [TableMatch], caretLocation: Int) -> SQLContext.TableReference? {
        guard !matches.isEmpty else { return nil }
        let candidate = matches.last { NSMaxRange($0.range) <= caretLocation } ?? matches.last!
        return SQLContext.TableReference(schema: candidate.schema,
                                         name: candidate.name,
                                         alias: candidate.alias,
                                         matchLocation: candidate.range.location)
    }

    private static func normalizeIdentifier(_ value: String) -> String {
        var identifier = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = identifier.firstIndex(where: { $0.isWhitespace }) {
            identifier = String(identifier[..<spaceIndex])
        }
        identifier = identifier.trimmingCharacters(in: CharacterSet(charactersIn: ",;()"))
        let removable: Set<Character> = ["\"", "'", "[", "]", "`"]
        identifier.removeAll(where: { removable.contains($0) })
        return identifier
    }

    private static func isValidIdentifier(_ value: String) -> Bool {
        guard let first = value.unicodeScalars.first else { return false }
        let startSet = CharacterSet.letters.union(CharacterSet(charactersIn: "_"))
        let bodySet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard startSet.contains(first) else { return false }
        return value.unicodeScalars.dropFirst().allSatisfy { bodySet.contains($0) }
    }

    private static let completionTokenCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "$_.")
        return set
    }()

    private static let nonWordCharacterSet: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "_$")
        return set.inverted
    }()

    static let objectContextKeywords: Set<String> = [
        "from", "join", "inner", "left", "right", "full", "outer", "cross", "update", "into", "delete"
    ]

    private static let aliasTerminatingKeywords: Set<String> = [
        "WHERE", "INNER", "LEFT", "RIGHT", "ON", "JOIN", "SET", "ORDER", "GROUP", "HAVING", "LIMIT"
    ]

    static let columnContextKeywords: Set<String> = [
        "select", "where", "on", "and", "or", "having", "group", "order", "by", "set", "values", "case", "when", "then", "else", "returning", "using"
    ]
}
