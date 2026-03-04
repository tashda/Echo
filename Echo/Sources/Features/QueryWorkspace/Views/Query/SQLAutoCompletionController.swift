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

    private let popover: NSPopover
#if os(macOS)
    private var hostingController: NSHostingController<AutoCompletionListView>?
#else
    private var hostingController: UIHostingController<AutoCompletionListView>?
#endif
    private var flatSuggestions: [SQLAutoCompletionSuggestion] = []
    private var selectedIndex: Int = 0
    private var lastQuery: SQLAutoCompletionQuery?
    private var detailResetToken = UUID()

    private let minWidth: CGFloat = 200
    private let maxWidth: CGFloat = 420
    private let maxHeight: CGFloat = 260

    init(textView: SQLTextView) {
        self.textView = textView
        self.popover = NSPopover()
        popover.behavior = .semitransient
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

        let suppressPopover = textView.consumePopoverSuppressionFlag()
        let keywordSuggestions = inlineKeywordCandidates(from: suggestions, query: query)
        if textView.displayOptions.inlineKeywordSuggestionsEnabled,
           let inlineSuggestions = keywordSuggestions {
            if popover.isShown {
                popover.performClose(nil)
            }
            flatSuggestions.removeAll(keepingCapacity: false)
            selectedIndex = 0
            lastQuery = query
            textView.showInlineKeywordSuggestions(inlineSuggestions, query: query)
            return
        } else {
            textView.hideInlineKeywordSuggestion()
        }

        if suppressPopover {
            hide()
            return
        }

        let appearance = textView.window?.effectiveAppearance ?? textView.effectiveAppearance
        popover.appearance = appearance
        hostingController?.view.appearance = appearance

        let previousID = selectedSuggestion?.id
        var filtered = suggestions
        if !textView.displayOptions.suggestKeywordsInCompletion {
            filtered.removeAll { $0.kind == .keyword }
        }
        flatSuggestions = filtered
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

        updateContent()

        guard textView.window != nil,
              let caretRect = caretRect(for: query) else {
            hide()
            return
        }

        popover.show(relativeTo: caretRect, of: textView, preferredEdge: .maxY)
    }

    func hide() {
        textView?.hideInlineKeywordSuggestion()
        flatSuggestions.removeAll(keepingCapacity: false)
        lastQuery = nil
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

    private func ensureHostingController() -> NSHostingController<AutoCompletionListView> {
        if let hostingController { return hostingController }
#if os(macOS)
        let controller = NSHostingController(
            rootView: AutoCompletionListView(
                suggestions: [],
                selectedID: nil,
                onSelect: { _ in },
                detailResetID: detailResetToken,
                statusMessage: nil
            )
        )
#else
        let controller = UIHostingController(
            rootView: AutoCompletionListView(
                suggestions: [],
                selectedID: nil,
                onSelect: { _ in },
                detailResetID: detailResetToken,
                statusMessage: nil
            )
        )
#endif
        controller.view.translatesAutoresizingMaskIntoConstraints = false
        popover.contentViewController = controller
        hostingController = controller
        return controller
    }

    private func updateContent() {
        let controller = ensureHostingController()
        let statusMessage = SQLAutoCompletionController.statusMessage(isMetadataLimited: textView?.completionEngine.isMetadataLimited == true)
        let updatedView = AutoCompletionListView(
            suggestions: flatSuggestions,
            selectedID: selectedSuggestion?.id,
            onSelect: { [weak self] suggestion in
                // Ensure the accept action runs on the main actor even if the
                // callback is invoked from a nonisolated context.
                Task { @MainActor in
                    self?.accept(suggestion)
                }
            },
            detailResetID: detailResetToken,
            statusMessage: statusMessage
        )
        controller.rootView = updatedView

        controller.view.layoutSubtreeIfNeeded()
        var fittingSize = controller.view.fittingSize
        fittingSize.width = ceil(fittingSize.width)
        fittingSize.height = ceil(fittingSize.height)
        let width = min(maxWidth, max(minWidth, fittingSize.width))
        let height = min(maxHeight, max(72, fittingSize.height))
        popover.contentSize = NSSize(width: width, height: height)
    }

    private func inlineKeywordCandidates(from suggestions: [SQLAutoCompletionSuggestion],
                                         query: SQLAutoCompletionQuery) -> [SQLAutoCompletionSuggestion]? {
        guard !suggestions.isEmpty else { return nil }
        guard query.pathComponents.isEmpty else { return nil }

        // Avoid inline keyword suggestions in object/alias positions inside
        // FROM / JOIN target clauses. Once at least one table is in scope,
        // inline SQL syntax (e.g. "FROM", "FULL JOIN") tends to be noisy when
        // the user is naming an alias.
        switch query.clause {
        case .from, .joinTarget:
            if !query.tablesInScope.isEmpty {
                return nil
            }
        default:
            break
        }

        var loweredPrefix = query.prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if loweredPrefix.isEmpty {
            loweredPrefix = query.token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }

        let keywordSuggestions = suggestions.filter { suggestion in
            guard suggestion.kind == .keyword else { return false }
            let keyword = suggestion.insertText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            if !loweredPrefix.isEmpty {
                return keyword.hasPrefix(loweredPrefix)
            }

            if let preceding = query.precedingCharacter {
                return preceding.isWhitespace
            }

            return true
        }

        return keywordSuggestions.isEmpty ? nil : keywordSuggestions
    }

    static func statusMessage(isMetadataLimited: Bool) -> String? {
        isMetadataLimited ? "Limited metadata — showing keywords and history" : nil
    }

    private func moveSelection(_ delta: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let count = flatSuggestions.count
        let newIndex = (selectedIndex + delta) % count
        selectedIndex = newIndex >= 0 ? newIndex : newIndex + count
        updateContent()
    }

    private func pageSelection(_ direction: Int) {
        guard !flatSuggestions.isEmpty else { return }
        let pageSize = 8
        moveSelection(direction > 0 ? pageSize : -pageSize)
    }

    private func accept(_ suggestion: SQLAutoCompletionSuggestion) {
        guard let textView else { return }
        let query = lastQuery ?? textView.currentCompletionQuery()
        guard let query else { hide(); return }
        textView.applyCompletion(suggestion, query: query)
    }

    private var selectedSuggestion: SQLAutoCompletionSuggestion? {
        guard selectedIndex >= 0, selectedIndex < flatSuggestions.count else { return nil }
        return flatSuggestions[selectedIndex]
    }

    private func caretRect(for query: SQLAutoCompletionQuery) -> NSRect? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        var queryRange = query.replacementRange
        if queryRange.length == 0 && queryRange.location > 0 {
            queryRange = NSRange(location: max(queryRange.location - 1, 0), length: 1)
        }

        var glyphRange = layoutManager.glyphRange(forCharacterRange: queryRange, actualCharacterRange: nil)
        if glyphRange.length == 0 && glyphRange.location > 0 {
            glyphRange = NSRange(location: max(glyphRange.location - 1, 0), length: 1)
        }

        var caretRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        caretRect.origin.x += textView.textContainerInset.width
        caretRect.origin.y += textView.textContainerInset.height
        caretRect.origin.y += caretRect.height
        caretRect.origin.y += 4

        caretRect.size.width = max(caretRect.width, 2)
        caretRect.size.height = max(caretRect.height, 18)
        return caretRect
    }
}
