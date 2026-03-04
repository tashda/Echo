#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    internal func filteredSuggestions(from sections: [SQLAutoCompletionSection], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let flattened = sections.flatMap { $0.suggestions }
        return sanitizeSuggestions(flattened, for: query)
    }

    internal func sanitizeSuggestions(_ suggestions: [SQLAutoCompletionSuggestion], for query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let trimmedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenLower = trimmedToken.lowercased()
        let normalizedToken = normalizeIdentifier(trimmedToken).lowercased()
        let pathLower = query.pathComponents.map { $0.lowercased() }
        let caretLocation = selectedRange().location
        let usedColumnContext = buildUsedColumnContext(before: caretLocation, query: query)
        var seen = Set<String>()
        var result: [SQLAutoCompletionSuggestion] = []
        result.reserveCapacity(suggestions.count)

        let suppressNonColumnInSelectList = query.clause == .selectList && trimmedToken.isEmpty && query.pathComponents.isEmpty && !completionEngine.isManualTriggerActive

        for suggestion in suggestions {
            guard isSuggestionKindEnabled(suggestion.kind) else { continue }
            if suppressNonColumnInSelectList && suggestion.kind != .column {
                continue
            }
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty {
                let isExactInsertMatch = key == tokenLower
                let isExactPathMatch: Bool = {
                    guard !pathLower.isEmpty else { return false }
                    let candidate = (pathLower + [key]).joined(separator: ".")
                    return candidate == tokenLower
                }()

                if (isExactInsertMatch || isExactPathMatch),
                   (suggestion.kind == .keyword || suggestion.kind == .function) {
                    continue
                }
            }

            if suggestion.kind == .column,
               let context = usedColumnContext,
               let columnName = normalizedColumnName(for: suggestion) {
                if context.unqualified.contains(columnName) {
                    continue
                }
                let candidateKeys = candidateColumnKeys(for: suggestion, query: query)
                let isAlreadySelected = candidateKeys.contains { key in
                    guard let used = context.byKey[key] else { return false }
                    return used.contains(columnName)
                }
                if isAlreadySelected {
                    continue
                }
                if !normalizedToken.isEmpty && columnName == normalizedToken {
                    continue
                }
            }

            if seen.insert(key).inserted {
                result.append(suggestion)
            }
        }
        return result
    }

    internal func mergeSuggestions(primary: [SQLAutoCompletionSuggestion],
                                  secondary: [SQLAutoCompletionSuggestion],
                                  query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        let tokenLower = query.token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen = Set(primary.map { $0.insertText.lowercased() })
        var combined = primary
        combined.reserveCapacity(primary.count + secondary.count)

        for suggestion in secondary {
            let key = suggestion.insertText.lowercased()
            if !tokenLower.isEmpty && key == tokenLower { continue }
            if seen.insert(key).inserted {
                combined.append(suggestion)
            }
        }
        return combined
    }

    internal func filterSuggestionsForContext(_ suggestions: [SQLAutoCompletionSuggestion],
                                     query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion] {
        guard !suggestions.isEmpty else { return suggestions }

        var filtered = suggestions

        // Avoid suggesting a redundant FROM keyword once the current SELECT
        // statement already contains a FROM clause before the caret.
        if hasExistingFromKeywordInCurrentSelectSegment() {
            filtered.removeAll { suggestion in
                guard suggestion.kind == .keyword else { return false }
                let keyword = suggestion.insertText
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                return keyword == "from"
            }
        }

        return filtered
    }

    private func hasExistingFromKeywordInCurrentSelectSegment() -> Bool {
        let selection = selectedRange()
        let caretLocation = selection.location
        guard caretLocation != NSNotFound else { return false }

        let nsString = string as NSString
        guard caretLocation <= nsString.length else { return false }

        let searchSelectRange = NSRange(location: 0, length: caretLocation)
        let selectRange = nsString.range(of: "select",
                                         options: [.caseInsensitive, .backwards],
                                         range: searchSelectRange)
        guard selectRange.location != NSNotFound else { return false }

        let fromSearchStart = selectRange.upperBound
        guard fromSearchStart < caretLocation else { return false }

        let fromSearchRange = NSRange(location: fromSearchStart,
                                      length: caretLocation - fromSearchStart)
        var searchLocation = fromSearchRange.location
        let searchUpperBound = NSMaxRange(fromSearchRange)

        while searchLocation < searchUpperBound {
            let remainingLength = searchUpperBound - searchLocation
            let searchRange = NSRange(location: searchLocation, length: remainingLength)
            let fromRange = nsString.range(of: "from",
                                           options: [.caseInsensitive],
                                           range: searchRange)
            if fromRange.location == NSNotFound { break }

            if isWholeWord(range: fromRange, in: nsString) {
                return true
            }

            searchLocation = fromRange.location + fromRange.length
        }

        return false
    }

    internal func limitSuggestions(_ suggestions: [SQLAutoCompletionSuggestion]) -> [SQLAutoCompletionSuggestion] {
        let maximum = 60
        return suggestions.count > maximum ? Array(suggestions.prefix(maximum)) : suggestions
    }

    internal func fetchSqruffSuggestions(for query: SQLAutoCompletionQuery,
                                        text: String,
                                        caretLocation: Int,
                                        context: SQLEditorCompletionContext) async -> [SQLAutoCompletionSuggestion] {
        guard caretLocation != NSNotFound else { return [] }
        let nsString = text as NSString
        let boundedLocation = max(0, min(caretLocation, nsString.length))
        let position = cursorPosition(for: boundedLocation, in: nsString)

        do {
            var suggestions = try await sqruffProvider.completions(
                forText: text,
                line: position.line,
                character: position.character,
                dialect: DatabaseType(context.databaseType)
            )
            suggestions = sanitizeSuggestions(suggestions, for: query)
            return suggestions
        } catch {
            return []
        }
    }

    private func cursorPosition(for location: Int, in string: NSString) -> (line: Int, character: Int) {
        var line = 0
        var column = 0
        var index = 0
        let length = string.length
        while index < location && index < length {
            let char = string.character(at: index)
            if char == 10 { // \n
                line += 1
                column = 0
            } else if char == 13 { // \r
                if index + 1 < location && index + 1 < length && string.character(at: index + 1) == 10 {
                    index += 1
                }
                line += 1
                column = 0
            } else {
                column += 1
            }
            index += 1
        }
        return (line, column)
    }

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

    private func extractTablesFallback(from text: String) -> [SQLAutoCompletionTableFocus] {
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

    private func buildUsedColumnContext(before caretLocation: Int, query: SQLAutoCompletionQuery) -> UsedColumnContext? {
        guard caretLocation != NSNotFound else { return nil }
        let nsString = string as NSString
        let clampedLocation = min(max(caretLocation, 0), nsString.length)

        let searchSelectRange = NSRange(location: 0, length: clampedLocation)
        let selectRange = nsString.range(of: "select", options: [.caseInsensitive, .backwards], range: searchSelectRange)
        guard selectRange.location != NSNotFound else { return nil }

        let fromSearchRange = NSRange(location: selectRange.upperBound, length: nsString.length - selectRange.upperBound)
        let fromRange = nsString.range(of: "from", options: [.caseInsensitive], range: fromSearchRange)

        let segmentEnd = fromRange.location != NSNotFound ? fromRange.location : nsString.length
        guard segmentEnd > selectRange.upperBound else { return nil }

        let segmentRange = NSRange(location: selectRange.upperBound, length: segmentEnd - selectRange.upperBound)
        let segment = nsString.substring(with: segmentRange)
        var context = UsedColumnContext(byKey: [:], unqualified: [])
        let scopeTables = query.tablesInScope

        for part in segment.split(separator: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let identifier = leadingIdentifier(in: trimmed) else { continue }
            let loweredIdentifier = identifier.lowercased()
            let components = loweredIdentifier.split(separator: ".", omittingEmptySubsequences: true)
            guard let columnComponent = components.last else { continue }
            let columnName = String(columnComponent)

            if components.count > 1 {
                let qualifierComponent = components[components.count - 2]
                let qualifier = String(qualifierComponent)
                if let aliasKeyValue = aliasKey(qualifier) {
                    context.byKey[aliasKeyValue, default: []].insert(columnName)
                }
                if let focus = tableFocus(forQualifier: qualifier, in: scopeTables) {
                    let key = tableKey(for: focus)
                    context.byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                        context.byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            } else {
                context.unqualified.insert(columnName)
                if scopeTables.count == 1 {
                    let focus = scopeTables[0]
                    let key = tableKey(for: focus)
                    context.byKey[key, default: []].insert(columnName)
                    if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                        context.byKey[focusAliasKey, default: []].insert(columnName)
                    }
                }
            }
        }

        return context.byKey.isEmpty && context.unqualified.isEmpty ? nil : context
    }

    private func leadingIdentifier(in expression: String) -> String? {
        var buffer = ""
        for character in expression {
            if character.isLetter || character.isNumber || character == "_" || character == "." || character == "\"" || character == "`" || character == "[" || character == "]" {
                buffer.append(character)
            } else {
                break
            }
        }
        guard !buffer.isEmpty else { return nil }
        let normalized = normalizeIdentifier(buffer)
        return normalized.isEmpty ? nil : normalized
    }

    private func tableFocus(forQualifier qualifier: String, in tables: [SQLAutoCompletionTableFocus]) -> SQLAutoCompletionTableFocus? {
        let normalizedQualifier = normalizeIdentifier(qualifier).lowercased()
        if let aliasMatch = tables.first(where: { $0.alias?.lowercased() == normalizedQualifier }) {
            return aliasMatch
        }
        if let nameMatch = tables.first(where: { $0.name.lowercased() == normalizedQualifier }) {
            return nameMatch
        }
        return nil
    }

    private func tableKey(for focus: SQLAutoCompletionTableFocus) -> String {
        tableKey(schema: focus.schema, name: focus.name)
    }

    private func tableKey(schema: String?, name: String) -> String {
        let schemaComponent = schema.map { normalizeIdentifier($0).lowercased() } ?? ""
        let nameComponent = normalizeIdentifier(name).lowercased()
        return "\(schemaComponent)|\(nameComponent)"
    }

    private func aliasKey(_ alias: String) -> String? {
        let normalized = normalizeIdentifier(alias).lowercased()
        return normalized.isEmpty ? nil : "alias:\(normalized)"
    }

    private func aliasKeys(for origin: SQLAutoCompletionSuggestion.Origin, tables: [SQLAutoCompletionTableFocus]) -> [String] {
        guard let object = origin.object else { return [] }
        let objectName = normalizeIdentifier(object).lowercased()
        let schemaName = origin.schema.map { normalizeIdentifier($0).lowercased() }
        return tables.compactMap { focus in
            guard normalizeIdentifier(focus.name).lowercased() == objectName else { return nil }
            if let schemaName,
               let focusSchema = focus.schema.map({ normalizeIdentifier($0).lowercased() }),
               focusSchema != schemaName {
                return nil
            }
            guard let alias = focus.alias, let key = aliasKey(alias) else { return nil }
            return key
        }
    }

    private func candidateColumnKeys(for suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) -> [String] {
        var keys: Set<String> = []

        if let origin = suggestion.origin,
           let object = origin.object, !object.isEmpty {
            keys.insert(tableKey(schema: origin.schema, name: object))
            aliasKeys(for: origin, tables: query.tablesInScope).forEach { keys.insert($0) }
        }

        let normalizedInsert = normalizeIdentifier(suggestion.insertText).lowercased()
        let components = normalizedInsert.split(separator: ".", omittingEmptySubsequences: true)
        if components.count > 1 {
            let qualifier = String(components[components.count - 2])
            if let qualifierKey = aliasKey(qualifier) {
                keys.insert(qualifierKey)
            }
            if let focus = tableFocus(forQualifier: qualifier, in: query.tablesInScope) {
                keys.insert(tableKey(for: focus))
                if let alias = focus.alias, let focusAliasKey = aliasKey(alias) {
                    keys.insert(focusAliasKey)
                }
            }
        }

        return Array(keys)
    }

    private struct UsedColumnContext {
        var byKey: [String: Set<String>]
        var unqualified: Set<String>
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

    private func normalizedColumnName(for suggestion: SQLAutoCompletionSuggestion) -> String? {
        if let column = suggestion.origin?.column, !column.isEmpty {
            return normalizeIdentifier(column).lowercased()
        }
        let normalized = normalizeIdentifier(suggestion.insertText)
        let components = normalized.split(separator: ".", omittingEmptySubsequences: true)
        guard let last = components.last else { return nil }
        return String(last).lowercased()
    }
}
#endif
