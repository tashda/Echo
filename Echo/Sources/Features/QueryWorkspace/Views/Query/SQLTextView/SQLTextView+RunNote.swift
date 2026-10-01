#if os(macOS)
import EchoSense
import AppKit
import SwiftUI

/// QE2, round 28.7: after a run, a glass pill (R10) after the last line of each statement that ran
/// (MS0), centred on that line.
extension SQLTextView {
    func showRunNotes() {
        runNoteViews.forEach { $0.removeFromSuperview() }
        runNoteViews = runNotes.compactMap(makeRunNoteView)
    }

    private func makeRunNoteView(_ note: QueryRunNote) -> NSView? {
        guard let layoutManager, let textContainer else { return nil }
        let text = string as NSString
        let end = min(NSMaxRange(note.range), text.length)
        guard end > 0 else { return nil }
        let lastLine = text.lineRange(for: NSRange(location: max(end - 1, 0), length: 0))
        let trimmedLength = max(lastLine.length - (text.substring(with: lastLine).hasSuffix("\n") ? 1 : 0), 1)
        let glyphs = layoutManager.glyphRange(forCharacterRange: NSRange(location: lastLine.location, length: trimmedLength), actualCharacterRange: nil)
        let lineRect = layoutManager.boundingRect(forGlyphRange: glyphs, in: textContainer)
        let fragment = layoutManager.lineFragmentRect(forGlyphAt: max(NSMaxRange(glyphs) - 1, glyphs.location), effectiveRange: nil)

        let view = NSHostingView(rootView: RunNotePill(note: note))
        let size = view.fittingSize
        view.frame = NSRect(
            x: lineRect.maxX + textContainerOrigin.x + LayoutTokens.EditorGutter.runNoteGap,
            y: fragment.midY + textContainerOrigin.y - size.height / 2,
            width: size.width, height: size.height
        )
        addSubview(view)
        return view
    }
}
#endif
