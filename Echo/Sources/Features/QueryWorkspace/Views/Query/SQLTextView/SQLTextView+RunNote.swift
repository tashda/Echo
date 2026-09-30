#if os(macOS)
import AppKit

/// QE2: the run note after the last line of what ran, in green for results, red for an error.
extension SQLTextView {
    func showRunNote() {
        guard let note = runNote, let layoutManager, let textContainer else {
            runNoteLabel?.isHidden = true
            return
        }
        let text = string as NSString
        let end = min(NSMaxRange(note.range), text.length)
        guard end > 0 else { runNoteLabel?.isHidden = true; return }
        let lastLine = text.lineRange(for: NSRange(location: max(end - 1, 0), length: 0))
        let trimmedLength = max(lastLine.length - (text.substring(with: lastLine).hasSuffix("\n") ? 1 : 0), 1)
        let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: lastLine.location, length: trimmedLength), actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)

        let label = runNoteLabel ?? makeRunNoteLabel()
        label.stringValue = note.text
        label.textColor = note.isError ? .systemRed : note.isWarning ? .systemOrange : .systemGreen
        label.toolTip = note.detail
        label.sizeToFit()
        label.frame.origin = NSPoint(
            x: lineRect.maxX + textContainerOrigin.x + LayoutTokens.EditorGutter.runNoteGap,
            y: lineRect.minY + textContainerOrigin.y + (lineRect.height - label.frame.height) / 2
        )
        label.isHidden = false
    }

    private func makeRunNoteLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.font = TypographyTokens.AppKit.detail
        label.isSelectable = false
        addSubview(label)
        runNoteLabel = label
        return label
    }
}
#endif
