#if os(macOS)
import AppKit

/// Round 28.15: marks on the text in the editor's language (EditorMarkTokens): as high as the
/// letters, a little wider, the corner from Settings › Editor › Marks, coloured by meaning, soft or
/// strong, scaled by Marks › Strength.
extension SQLTextView {
    /// One rectangle per line the range covers, in the text view's coordinates.
    func markRects(for range: NSRange) -> [NSRect] {
        guard let layoutManager, let textContainer, range.location != NSNotFound, range.length > 0,
              NSMaxRange(range) <= (string as NSString).length else { return [] }
        let font = theme.nsFont
        let baseline = (layoutManager as? SQLLayoutManager)?.fixedBaselineOffset ?? font.ascender
        let vertical = EditorMarkTokens.verticalPadding
        let side = EditorMarkTokens.sidePadding
        let height = ceil(font.ascender - font.descender) + vertical * 2
        var rects: [NSRect] = []
        let glyphs = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphs, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: textContainer) { fragment, _ in
            rects.append(NSRect(x: fragment.minX + self.textContainerOrigin.x - side,
                                y: fragment.minY + self.textContainerOrigin.y + baseline - font.ascender - vertical,
                                width: fragment.width + side * 2, height: height))
        }
        return rects
    }

    /// The fill for a mark of this meaning and strength.
    func markColor(_ meaning: EditorMarkTokens.Meaning, _ strength: EditorMarkTokens.Strength) -> NSColor {
        meaning.nsColor.withAlphaComponent(min(strength.opacity * displayOptions.markStrength.multiplier, 1))
    }

    /// Fills the marks of a range that fall inside `dirty`.
    func fillMarks(for range: NSRange, _ meaning: EditorMarkTokens.Meaning, _ strength: EditorMarkTokens.Strength, in dirty: NSRect) {
        markColor(meaning, strength).setFill()
        for rect in markRects(for: range) where rect.intersects(dirty) {
            let radius = displayOptions.markCorners.radius(forHeight: rect.height)
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
        }
    }
}
#endif
