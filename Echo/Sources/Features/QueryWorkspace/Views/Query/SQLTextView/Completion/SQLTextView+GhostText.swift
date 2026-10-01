#if os(macOS)
import AppKit
import EchoSense

/// ES3 (design board, 2026-09-30), a setting: the best suggestion's remaining letters in grey
/// after the caret. Tab accepts it; any other key carries on typing; the full list opens with
/// the EchoSense shortcut.
extension SQLTextView {
    /// The part of the suggestion still to type, when it continues what was typed.
    static func ghostSuffix(for suggestion: SQLAutoCompletionSuggestion, typed token: String) -> String? {
        let insert = suggestion.insertText
        guard !token.isEmpty, insert.count > token.count,
              insert.lowercased().hasPrefix(token.lowercased()) else { return nil }
        return String(insert.dropFirst(token.count))
    }

    func showGhostText(for response: SQLCompletionResponse) {
        guard let top = response.suggestions.first,
              let suffix = Self.ghostSuffix(for: top, typed: response.token),
              let caretRect = ghostCaretRect() else {
            hideGhostText()
            return
        }
        let label = ghostTextLabel ?? makeGhostLabel()
        label.stringValue = suffix
        label.font = theme.font.font
        label.sizeToFit()
        label.frame.origin = NSPoint(x: caretRect.maxX, y: caretRect.minY + (caretRect.height - label.frame.height) / 2)
        label.isHidden = false
        ghostSuggestion = (top, response)
    }

    func hideGhostText() {
        ghostSuggestion = nil
        ghostTextLabel?.isHidden = true
    }

    /// Tab accepts the ghost text; everything else leaves it to the next completion pass.
    func acceptGhostTextIfNeeded(_ event: NSEvent) -> Bool {
        guard let ghost = ghostSuggestion else { return false }
        if event.keyCode == 48, !event.modifierFlags.contains(.shift) {
            hideGhostText()
            applyCompletion(ghost.suggestion, response: ghost.response)
            return true
        }
        if event.keyCode == 53 {
            hideGhostText()
            return true
        }
        hideGhostText()
        return false
    }

    private func makeGhostLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.textColor = .tertiaryLabelColor
        label.isSelectable = false
        label.setAccessibilityElement(false)
        addSubview(label)
        ghostTextLabel = label
        return label
    }

    /// The caret's position in the text view, from the character before it.
    private func ghostCaretRect() -> NSRect? {
        let caret = selectedRange()
        guard caret.length == 0, caret.location > 0, let layoutManager, let textContainer else { return nil }
        let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: caret.location - 1, length: 1), actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }
}
#endif
