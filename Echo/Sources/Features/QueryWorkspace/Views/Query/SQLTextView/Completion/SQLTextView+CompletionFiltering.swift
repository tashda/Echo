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
        var seen = Set<String>()
        var result: [SQLAutoCompletionSuggestion] = []
        result.reserveCapacity(suggestions.count)

        for suggestion in suggestions {
            guard isSuggestionKindEnabled(suggestion.kind) else { continue }

            // Suppress exact-match keywords/functions (user already typed the complete word)
            if !tokenLower.isEmpty {
                let key = suggestion.insertText.lowercased()
                let isExactMatch = key == tokenLower
                if isExactMatch && (suggestion.kind == .keyword || suggestion.kind == .function) {
                    continue
                }
            }

            let deduplicationKey = suggestion.insertText.lowercased()
            if seen.insert(deduplicationKey).inserted {
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
