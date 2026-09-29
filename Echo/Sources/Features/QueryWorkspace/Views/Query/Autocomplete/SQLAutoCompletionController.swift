import SwiftUI
import EchoSense
import AppKit

/// Shows EchoSense's suggestions under the caret in a borderless panel and handles the keys the
/// editor forwards while it is open.
@MainActor
final class SQLAutoCompletionController {
    weak var textView: SQLTextView?

    let panel = SQLCompletionPanel()
    var hostingView: NSHostingView<AutoCompletionListView>?
    var flatSuggestions: [SQLAutoCompletionSuggestion] = []
    var selectedIndex: Int = 0
    /// True once the selection moved with the arrow keys; typing sets it back (ESR4).
    var isChoosing = false
    var lastQuery: SQLAutoCompletionQuery?
    var lastResponse: SQLCompletionResponse?
    var anchorRange: NSRange?
    var dismissalMonitor: Any?
    var dismissalObservers: [NSObjectProtocol] = []

    init(textView: SQLTextView) {
        self.textView = textView
        panel.appearance = textView.effectiveAppearance
    }

    private var isVisible: Bool { panel.isVisible && !flatSuggestions.isEmpty }

    var isPresenting: Bool { isVisible }

    func present(suggestions: [SQLAutoCompletionSuggestion], query: SQLAutoCompletionQuery) {
        lastQuery = query
        show(suggestions, replacementRange: query.replacementRange)
    }

    func present(suggestions: [SQLAutoCompletionSuggestion], response: SQLCompletionResponse) {
        lastResponse = response
        show(suggestions, replacementRange: response.replacementRange)
    }

    private func show(_ suggestions: [SQLAutoCompletionSuggestion], replacementRange: NSRange) {
        guard let textView, textView.window != nil, !suggestions.isEmpty else {
            hide()
            return
        }
        panel.appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance

        let previousID = selectedSuggestion?.id
        flatSuggestions = suggestions
        selectedIndex = previousID.flatMap { id in flatSuggestions.firstIndex { $0.id == id } } ?? 0
        isChoosing = false
        anchorRange = replacementRange

        updatePanelContent()
        guard positionPanel() else {
            hide()
            return
        }
        attachPanel()
    }

    func hide() {
        flatSuggestions.removeAll(keepingCapacity: false)
        lastQuery = nil
        lastResponse = nil
        anchorRange = nil
        selectedIndex = 0
        isChoosing = false
        detachPanel()
    }

    func handleKeyDown(_ event: NSEvent) -> Bool {
        guard isVisible else { return false }

        switch event.keyCode {
        case 125: // down arrow
            moveSelection(1)
            return true
        case 126: // up arrow
            moveSelection(-1)
            return true
        case 121: // page down
            moveSelection(LayoutTokens.EchoSense.visibleRows)
            return true
        case 116: // page up
            moveSelection(-LayoutTokens.EchoSense.visibleRows)
            return true
        case 53: // escape
            hide()
            textView?.activateManualCompletionSuppression()
            return true
        case 36, 76: // return, enter
            acceptCurrentSuggestion()
            return true
        default:
            break
        }

        if event.charactersIgnoringModifiers == "\t" {
            if event.modifierFlags.contains(.shift) {
                moveSelection(-1)
            } else {
                acceptCurrentSuggestion()
            }
            return true
        }

        return false
    }

    private func acceptCurrentSuggestion() {
        guard let suggestion = selectedSuggestion else {
            hide()
            return
        }
        accept(suggestion)
    }

    private func moveSelection(_ delta: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let count = flatSuggestions.count
        let newIndex = (selectedIndex + delta) % count
        selectedIndex = newIndex >= 0 ? newIndex : newIndex + count
        isChoosing = true
        updatePanelContent()
        _ = positionPanel()
    }

    func accept(_ suggestion: SQLAutoCompletionSuggestion) {
        guard let textView else { return }
        // Prefer response-based acceptance (new API), fall back to query-based (legacy)
        if let response = lastResponse ?? textView.lastCompletionResponse {
            textView.applyCompletion(suggestion, response: response)
        } else {
            let query = lastQuery ?? textView.currentCompletionQuery()
            guard let query else { hide(); return }
            textView.applyCompletion(suggestion, query: query)
        }
    }

    var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard selectedIndex >= 0, selectedIndex < flatSuggestions.count else { return nil }
        return flatSuggestions[selectedIndex]
    }
}
