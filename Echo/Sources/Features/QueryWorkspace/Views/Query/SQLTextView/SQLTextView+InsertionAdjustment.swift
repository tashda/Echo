#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    func snippetPlaceholderIndex(containing selection: NSRange) -> Int? {
        guard selection.location != NSNotFound else { return nil }
        for (index, placeholder) in activeSnippetPlaceholders.enumerated() {
            let placeholderRange = placeholder.range
            if selection.length == 0 {
                if NSLocationInRange(selection.location, placeholderRange) ||
                    selection.location == NSMaxRange(placeholderRange) {
                    return index
                }
            } else {
                let start = selection.location
                let end = NSMaxRange(selection)
                if start >= placeholderRange.location &&
                    end <= NSMaxRange(placeholderRange) {
                    return index
                }
            }
        }
        return nil
    }

    /// A name typed with quotes stays quoted (EchoSense's rule, shared with the scenarios).
    func adjustedInsertion(for suggestion: SQLAutoCompletionSuggestion,
                                   originalText: String,
                                   proposedInsertion: String) -> String {
        SQLEditorAcceptance.adjustedInsertion(for: suggestion, originalText: originalText, proposedInsertion: proposedInsertion)
    }

    internal func wrapComponent(_ component: String, using originalComponent: String) -> String {
        SQLEditorAcceptance.wrapComponent(component, using: originalComponent)
    }
}
#endif
