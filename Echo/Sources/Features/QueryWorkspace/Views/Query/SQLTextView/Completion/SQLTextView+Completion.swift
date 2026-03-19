#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    func applyCompletion(_ suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) {
        if isStarExpansionSuggestion(suggestion) {
            let context = completionContext
            Task { [weak self] in
                guard let self else { return }
                let formatted = await self.prepareStarExpansionInsertion(for: suggestion,
                                                                         context: context)
                await MainActor.run {
                    if self.performCompletionInsertion(suggestion: suggestion,
                                                       query: query,
                                                       insertion: formatted) != nil {
                        self.undoManager?.setActionName("Expand Columns")
                        self.completionEngine.clearPostCommitSuppression()
                    }
                }
            }
            return
        }

        if let snippetSource = suggestion.snippetText {
            let (insertion, placeholders) = makeSnippetInsertion(from: snippetSource)
            _ = performCompletionInsertion(suggestion: suggestion,
                                           query: query,
                                           insertion: insertion,
                                           snippetPlaceholders: placeholders)
            return
        }

        clearSnippetPlaceholders()
        var insertionText = suggestion.insertText
        if suggestion.kind == .keyword && !insertionText.hasSuffix(" ") {
            insertionText += " "
        }

        let insertionResult = performCompletionInsertion(suggestion: suggestion,
                                                         query: query,
                                                         insertion: insertionText)

        if insertionResult != nil, suggestion.kind == .schema {
            Task { @MainActor [weak self] in
                guard let self else { return }
                _ = self.forcePresentImmediateCompletions()
            }
        }
    }

    private struct CompletionInsertionResult {
        let appliedRange: NSRange
        let originalText: String
    }

    @discardableResult
    private func performCompletionInsertion(suggestion: SQLAutoCompletionSuggestion,
                                            query: SQLAutoCompletionQuery,
                                            insertion: String,
                                            snippetPlaceholders: [NSRange] = []) -> CompletionInsertionResult? {
        var range = query.replacementRange
        guard let textStorage else { return nil }
        let nsString = string as NSString

        if suggestion.kind != .column {
            var lowerBound = range.location
            let preserveQualifier = !query.pathComponents.isEmpty
            let period: unichar = 46
            while lowerBound > 0 {
                let character = nsString.character(at: lowerBound - 1)
                if preserveQualifier && character == period { break }
                if !isCompletionCharacter(character) { break }
                lowerBound -= 1
            }
            let upperBound = NSMaxRange(range)
            range = NSRange(location: lowerBound, length: upperBound - lowerBound)
        }

        let maxRange = nsString.length
        var upperBound = NSMaxRange(range)
        while upperBound < maxRange {
            let character = nsString.character(at: upperBound)
            if !isCompletionCharacter(character) { break }
            upperBound += 1
        }
        range.length = upperBound - range.location

        let originalText = nsString.substring(with: range)
        let finalInsertion: String
        if snippetPlaceholders.isEmpty {
            finalInsertion = adjustedInsertion(for: suggestion,
                                               originalText: originalText,
                                               proposedInsertion: insertion)
        } else {
            finalInsertion = insertion
        }

        guard shouldChangeText(in: range, replacementString: finalInsertion) else { return nil }

        isApplyingCompletion = true
        defer {
            isApplyingCompletion = false
            suppressNextCompletionRefresh = false
        }

        textStorage.replaceCharacters(in: range, with: finalInsertion)
        let insertionNSString = finalInsertion as NSString
        let insertionLength = insertionNSString.length
        let appliedRange = NSRange(location: range.location, length: insertionLength)
        finalizeAppliedCompletion(for: suggestion, appliedRange: appliedRange, insertion: insertionNSString)
        suppressNextCompletionRefresh = true

        if snippetPlaceholders.isEmpty {
            clearSnippetPlaceholders()
            let newLocation = NSMaxRange(appliedRange)
            setSelectedRange(NSRange(location: newLocation, length: 0))
        } else {
            let absolute = snippetPlaceholders.map { placeholder in
                NSRange(location: range.location + placeholder.location,
                        length: placeholder.length)
            }
            activateSnippetPlaceholders(absolute)
        }

        hideCompletions()
        didChangeText()
        completionEngine.recordSelection(suggestion, query: query)

        return CompletionInsertionResult(appliedRange: appliedRange, originalText: originalText)
    }

    private func isStarExpansionSuggestion(_ suggestion: SQLAutoCompletionSuggestion) -> Bool {
        suggestion.kind == .snippet && suggestion.id.hasPrefix("star|")
    }
}
#endif
