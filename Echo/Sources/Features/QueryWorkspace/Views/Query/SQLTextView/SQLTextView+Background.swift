#if os(macOS)
import AppKit

/// What the editor draws behind its text: the other uses of the word at the caret (round 28.5:
/// a soft tint as high as the letters, with Settings › Highlight Corners) and the empty prompt.
extension SQLTextView {
    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        drawWordHighlights(in: rect)
        drawEmptyPrompt()
    }

    private func drawWordHighlights(in rect: NSRect) {
        guard !selectionMatchRanges.isEmpty, let layoutManager, let textContainer else { return }
        let font = theme.nsFont
        let baseline = (layoutManager as? SQLLayoutManager)?.fixedBaselineOffset ?? font.ascender
        let lettersHeight = ceil(font.ascender - font.descender) + LayoutTokens.EditorGutter.highlightPadding * 2
        let radius = displayOptions.highlightCornerRadius
        NSColor.labelColor.withAlphaComponent(LayoutTokens.EditorGutter.highlightOpacity).setFill()
        let length = (string as NSString).length
        for range in selectionMatchRanges where NSMaxRange(range) <= length {
            let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                                  in: textContainer) { fragment, _ in
                let top = fragment.minY + baseline - font.ascender - LayoutTokens.EditorGutter.highlightPadding
                let mark = NSRect(x: fragment.minX + self.textContainerOrigin.x - LayoutTokens.EditorGutter.highlightPadding,
                                  y: top + self.textContainerOrigin.y,
                                  width: fragment.width + LayoutTokens.EditorGutter.highlightPadding * 2, height: lettersHeight)
                guard mark.intersects(rect) else { return }
                NSBezierPath(roundedRect: mark, xRadius: radius, yRadius: radius).fill()
            }
        }
    }
}
#endif
