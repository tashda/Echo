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
        let usedColumnContext = buildUsedColumnContextForFiltering(before: caretLocation, query: query)
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
               let columnName = normalizedColumnNameForFiltering(for: suggestion) {
                if context.unqualified.contains(columnName) {
                    continue
                }
                let candidateKeys = candidateColumnKeysForFiltering(for: suggestion, query: query)
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

}
#endif
