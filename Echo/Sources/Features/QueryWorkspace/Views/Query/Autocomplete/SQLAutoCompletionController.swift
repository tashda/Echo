import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class SQLAutoCompletionController {
    weak var textView: SQLTextView?

    let popover: NSPopover
#if os(macOS)
    var hostingController: NSHostingController<AutoCompletionListView>?
#else
    var hostingController: UIHostingController<AutoCompletionListView>?
#endif
    var flatSuggestions: [SQLAutoCompletionSuggestion] = []
    var selectedIndex: Int = 0
    var lastQuery: SQLAutoCompletionQuery?
    var lastResponse: SQLCompletionResponse?
    var detailResetToken = UUID()

    let minWidth: CGFloat = 200
    let maxWidth: CGFloat = 420
    let maxHeight: CGFloat = 260

    init(textView: SQLTextView) {
        self.textView = textView
        self.popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.appearance = textView.effectiveAppearance
    }

    deinit {
        // Avoid calling main-actor isolated AppKit APIs from deinit,
        // which runs in a nonisolated context under Swift Concurrency.
        // Popover will be torn down automatically when deallocated.
    }

    private var isVisible: Bool { popover.isShown && !flatSuggestions.isEmpty }

    var isPresenting: Bool { isVisible }

    func present(suggestions: [SQLAutoCompletionSuggestion], query: SQLAutoCompletionQuery) {
        guard let textView else {
            hide()
            return
        }

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        popover.appearance = appearance
        hostingController?.view.appearance = appearance

        let previousID = selectedSuggestion?.id
        flatSuggestions = suggestions
        guard !flatSuggestions.isEmpty else {
            hide()
            return
        }

        lastQuery = query

        if let previousID, let index = flatSuggestions.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }

        let shouldResetDetail = !popover.isShown
        if shouldResetDetail {
            detailResetToken = UUID()
        }

        updatePopoverContent()

        guard textView.window != nil,
              let caretRect = caretRectForQuery(query) else {
            hide()
            return
        }

        popover.show(relativeTo: caretRect, of: textView, preferredEdge: .maxY)
    }

    func present(suggestions: [SQLAutoCompletionSuggestion], response: SQLCompletionResponse) {
        guard let textView else {
            hide()
            return
        }

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        popover.appearance = appearance
        hostingController?.view.appearance = appearance

        let previousID = selectedSuggestion?.id
        flatSuggestions = suggestions
        guard !flatSuggestions.isEmpty else {
            hide()
            return
        }

        lastResponse = response

        if let previousID, let index = flatSuggestions.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }

        let shouldResetDetail = !popover.isShown
        if shouldResetDetail {
            detailResetToken = UUID()
        }

        updatePopoverContent()

        guard textView.window != nil,
              let caretRect = caretRectForResponse(response) else {
            hide()
            return
        }

        popover.show(relativeTo: caretRect, of: textView, preferredEdge: .maxY)
    }

    func hide() {
        flatSuggestions.removeAll(keepingCapacity: false)
        lastQuery = nil
        lastResponse = nil
        selectedIndex = 0
        if popover.isShown {
            popover.performClose(nil)
        }
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
            pageSelection(1)
            return true
        case 116: // page up
            pageSelection(-1)
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
        updatePopoverContent()
    }

    private func pageSelection(_ direction: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let pageSize = 8
        moveSelection(direction > 0 ? pageSize : -pageSize)
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
