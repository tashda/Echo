#if os(macOS)
import AppKit
import Foundation
import EchoSense

extension SQLTextView {
    func updateCompletionIndicator() {
        guard !isCompletionVisible else {
            removeCompletionIndicator()
            return
        }

        let selection = selectedRange()
        guard selection.location != NSNotFound else {
            removeCompletionIndicator()
            return
        }

        guard let (_, suppression) = suppressedCompletionEntry(containing: selection, caretLocation: selection.location) else {
            removeCompletionIndicator()
            return
        }

        guard suppression.hasFollowUps else {
            removeCompletionIndicator()
            return
        }

        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            removeCompletionIndicator()
            return
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: suppression.tokenRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else {
            removeCompletionIndicator()
            return
        }

        var boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        boundingRect.origin.x += textContainerInset.width
        boundingRect.origin.y += textContainerInset.height

        if completionIndicatorView == nil {
            let indicator = CompletionAccessoryView()
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.onActivate = { [weak self] in
                _ = self?.triggerSuppressedCompletionsIfAvailable()
            }
            addSubview(indicator)
            completionIndicatorView = indicator
        }

        completionIndicatorView?.update(for: boundingRect)
    }

    func removeCompletionIndicator() {
        completionIndicatorView?.removeFromSuperview()
        completionIndicatorView = nil
    }

    @discardableResult
    func triggerSuppressedCompletionsIfAvailable() -> Bool {
        let selection = selectedRange()
        guard selection.location != NSNotFound else { return false }
        let caretLocation = selection.location
        let indicatorVisible = completionIndicatorView?.isVisible == true

        guard indicatorVisible || suppressedCompletionEntry(containing: selection, caretLocation: caretLocation) != nil else {
            return false
        }

        return forcePresentImmediateCompletions()
    }

    func forcePresentImmediateCompletions() -> Bool {
        deactivateManualCompletionSuppression()
        clearSnippetPlaceholders()
        completionEngine.clearSuppression()
        suppressNextCompletionPopover = false

        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil

        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return false }

        let response = completionEngine.manualCompletions(in: string, at: caretLocation)
        lastCompletionResponse = response

        guard response.shouldShow else { return false }
        guard let controller = ensureCompletionController() else { return false }

        removeCompletionIndicator()
        controller.present(suggestions: response.suggestions, response: response)
        return true
    }

    func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard isCommandPeriod(event) else { return false }
        if triggerSuppressedCompletionsIfAvailable() {
            return true
        }
        return forcePresentImmediateCompletions()
    }

    func isCommandPeriod(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) else { return false }
        let periodKeyCode: UInt16 = 47
        if event.keyCode == periodKeyCode { return true }
        if let characters = event.charactersIgnoringModifiers, characters == "." {
            return true
        }
        return false
    }
}
#endif
