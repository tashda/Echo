#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func handleInlineSelectionChange() {
        if let range = inlineInsertedRange {
            let selection = selectedRange()
            if selection.length == 0, selection.location == NSMaxRange(range) {
                return
            }
            if selection.location != range.location || selection.length != range.length {
                hideInlineKeywordSuggestion()
            }
        } else if inlineSuggestionView != nil {
            updateInlineSuggestionPosition()
        }
    }

    func clearInlineSuggestionState() {
        inlineKeywordSuggestions.removeAll()
        inlineSuggestionQuery = nil
        inlineSuggestionNextIndex = 0
        inlineInsertedRange = nil
        inlineInsertedIndex = nil
    }

    func handleInlineSuggestionKey(_ event: NSEvent) -> Bool {
        guard let view = inlineSuggestionView,
              !view.isHidden,
              !inlineKeywordSuggestions.isEmpty else { return false }

        let index = min(max(inlineSuggestionNextIndex, 0), inlineKeywordSuggestions.count - 1)
        let suggestion = inlineKeywordSuggestions[index]

        if event.keyCode == 48 { // Tab
            acceptInlineSuggestion(suggestion)
            return true
        }

        if event.keyCode == 124 { // Right Arrow
            acceptInlineSuggestion(suggestion)
            return true
        }

        if event.keyCode == 125 || event.keyCode == 126 { // Down / Up
            inlineSuggestionNextIndex = (inlineSuggestionNextIndex + 1) % inlineKeywordSuggestions.count
            updateInlineSuggestionText()
            updateInlineSuggestionPosition()
            return true
        }

        if event.keyCode == 53 { // Escape
            hideInlineKeywordSuggestion()
            return true
        }

        return false
    }

    private func acceptInlineSuggestion(_ suggestion: SQLAutoCompletionSuggestion) {
        guard let query = inlineSuggestionQuery else { return }
        inlineAcceptanceInProgress = true
        applyCompletion(suggestion, query: query)
        inlineAcceptanceInProgress = false
        hideInlineKeywordSuggestion()
    }
}
#endif
