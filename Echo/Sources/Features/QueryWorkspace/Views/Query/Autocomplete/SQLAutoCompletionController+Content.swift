import SwiftUI
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension SQLAutoCompletionController {

    func ensureHostingControllerInstance() -> NSHostingController<AutoCompletionListView> {
        if let existing = hostingController { return existing }
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

    func updatePopoverContent() {
        let controller = ensureHostingControllerInstance()
        let statusMessage = SQLAutoCompletionController.statusMessage(isMetadataLimited: textView?.completionEngine.isMetadataLimited == true)
        let updatedView = AutoCompletionListView(
            suggestions: flatSuggestions,
            selectedID: selectedSuggestion?.id,
            onSelect: { [weak self] suggestion in
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

    static func statusMessage(isMetadataLimited: Bool) -> String? {
        isMetadataLimited ? "Limited metadata — showing keywords and history" : nil
    }

    func caretRectForQuery(_ query: SQLAutoCompletionQuery) -> NSRect? {
        caretRectForRange(query.replacementRange)
    }

    func caretRectForResponse(_ response: SQLCompletionResponse) -> NSRect? {
        caretRectForRange(response.replacementRange)
    }

    private func caretRectForRange(_ range: NSRange) -> NSRect? {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return nil }

        var queryRange = range
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
