#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    internal func tablesInScope(before location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation > 0 else { return [] }
        let prefixRange = NSRange(location: 0, length: clampedLocation)
        let substring = string.substring(with: prefixRange)
        return extractTables(from: substring)
    }

    internal func tablesInScope(after location: Int, in string: NSString) -> [SQLAutoCompletionTableFocus] {
        guard string.length > 0 else { return [] }
        let clampedLocation = min(max(location, 0), string.length)
        guard clampedLocation < string.length else { return [] }
        let suffixRange = NSRange(location: clampedLocation, length: string.length - clampedLocation)
        let substring = string.substring(with: suffixRange)
        guard !substring.isEmpty else { return [] }
        return extractTables(from: substring)
    }

    internal func extractTables(from text: String) -> [SQLAutoCompletionTableFocus] {
        guard !text.isEmpty else { return [] }

        let sourceNames = knownSourceNames()
        if sourceNames.isEmpty {
            return extractTablesFallback(from: text)
        }

        let knownNames = Set(sourceNames.map { $0.uppercased() })
        let tokens = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        for index in tokens.indices {
            guard let rawWord = lastWord(in: tokens[index]) else { continue }
            let normalizedWord = normalizeIdentifier(rawWord)
            guard !normalizedWord.isEmpty else { continue }
            let upperWord = normalizedWord.uppercased()
            guard knownNames.contains(upperWord) else { continue }

            guard index > 0 else { continue }
            let precedingKeyword = cleanedKeyword(tokens[index - 1])
            guard SQLTextView.objectContextKeywords.contains(precedingKeyword.lowercased()) else { continue }

            var alias: String?
            if index + 1 < tokens.count {
                var potentialAliasToken = tokens[index + 1]
                if potentialAliasToken.caseInsensitiveCompare("AS") == .orderedSame, index + 2 < tokens.count {
                    potentialAliasToken = tokens[index + 2]
                }
                let normalizedAlias = normalizeIdentifier(potentialAliasToken)
                let aliasUpper = normalizedAlias.uppercased()
                if !normalizedAlias.isEmpty,
                   !SQLTextView.aliasTerminatingKeywords.contains(aliasUpper),
                   SQLTextView.isValidIdentifier(normalizedAlias) {
                    alias = normalizedAlias
                }
            }

            let normalizedFullToken = normalizeIdentifier(tokens[index])
            let components = normalizedFullToken.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            let name = components.last ?? normalizedWord
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())|\(alias?.lowercased() ?? "")"
            guard unique.insert(key).inserted else { continue }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: alias))
        }

        if results.isEmpty {
            return extractTablesFallback(from: text)
        }

        return results
    }

    internal func extractTablesFallback(from text: String) -> [SQLAutoCompletionTableFocus] {
        let pattern = #"(?i)\b(from|join|update|into)\s+([A-Za-z0-9_\.\"`\[\]]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        var unique: Set<String> = []
        var results: [SQLAutoCompletionTableFocus] = []

        regex.enumerateMatches(in: text, options: [], range: nsRange) { match, _, _ in
            guard let match, match.numberOfRanges >= 3 else { return }
            let range = match.range(at: 2)
            guard let swiftRange = Range(range, in: text) else { return }
            let rawIdentifier = String(text[swiftRange])
            let normalized = normalizeIdentifier(rawIdentifier)
            guard !normalized.isEmpty else { return }
            let components = normalized.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
            guard let name = components.last else { return }
            let schema = components.dropLast().last
            let key = "\(schema?.lowercased() ?? "")|\(name.lowercased())"
            guard unique.insert(key).inserted else { return }
            results.append(SQLAutoCompletionTableFocus(schema: schema, name: name, alias: nil))
        }

        return results
    }

    internal func isSuggestionKindEnabled(_ kind: SQLAutoCompletionKind) -> Bool {
        switch kind {
        case .keyword:
            if displayOptions.suggestKeywordsInCompletion {
                return true
            }
            return displayOptions.inlineKeywordSuggestionsEnabled
        case .function:
            return displayOptions.suggestFunctionsInCompletion
        case .snippet:
            return displayOptions.suggestSnippetsInCompletion
        case .join:
            return displayOptions.suggestJoinsInCompletion
        case .parameter:
            return false
        default:
            return true
        }
    }

}
#endif
