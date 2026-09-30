#if os(macOS)
import EchoSense
import AppKit

/// QE1 (design board, 2026-09-30): when a script holds more than one statement, the statement at
/// the caret gets a faint band behind it and a Run arrow in the gutter that runs only it.
/// QE4: the caret's line is a rounded band inset from the card's edges.
extension SQLTextView {
    func refreshStatements() {
        let needsStatements = displayOptions.statementFocusEnabled || displayOptions.outlineEdgeEnabled
        cachedStatements = needsStatements ? SQLStatementAtCaret.statements(in: string) : []
        updateStatementFocus()
        if displayOptions.outlineEdgeEnabled { outlineStrip?.refresh() }
    }

    func updateStatementFocus() {
        let caret = selectedRange().location
        let focused: NSRange? = displayOptions.statementFocusEnabled && cachedStatements.count > 1 && caret != NSNotFound
            ? SQLStatementAtCaret.statement(among: cachedStatements, caret: caret)?.range
            : nil
        guard focused != focusedStatementRange else { return }
        focusedStatementRange = focused
        lineNumberRuler?.runArrowLine = focused.map { (string as NSString).lineNumber(at: $0.location) }
        lineNumberRuler?.onRunStatement = { [weak self] in
            guard let self else { return }
            self.sqlDelegate?.sqlTextViewDidRequestRunStatement(self)
        }
        setNeedsDisplay(visibleRect)
    }

    /// The caret's line, drawn as a rounded band; nil while text is selected.
    var currentLineBandRect: NSRect? {
        let selection = selectedRange()
        guard selection.length == 0, selection.location != NSNotFound, let layoutManager else { return nil }
        var lineRect: NSRect
        if selection.location >= (string as NSString).length, layoutManager.extraLineFragmentTextContainer != nil {
            lineRect = layoutManager.extraLineFragmentRect
        } else {
            let glyph = layoutManager.glyphIndexForCharacter(at: min(selection.location, max((string as NSString).length - 1, 0)))
            guard glyph < layoutManager.numberOfGlyphs else { return nil }
            lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
        }
        guard lineRect.height > 0 else { return nil }
        let inset = LayoutTokens.EditorGutter.currentLineInset
        return NSRect(x: inset, y: lineRect.minY + textContainerOrigin.y, width: max(bounds.width - inset * 2, 0), height: lineRect.height)
    }

    /// Redraws only the old and new current-line bands when the caret moves.
    func invalidateCurrentLineBand() {
        let next = currentLineBandRect
        if let lastCurrentLineBandRect { setNeedsDisplay(lastCurrentLineBandRect) }
        if let next { setNeedsDisplay(next) }
        lastCurrentLineBandRect = next
    }

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        if let band = currentLineBandRect, band.intersects(rect) {
            let radius = LayoutTokens.EditorGutter.currentLineCornerRadius
            theme.surfaces.currentLine.nsColor.setFill()
            NSBezierPath(roundedRect: band, xRadius: radius, yRadius: radius).fill()
        }
        drawResultStatementBand(in: rect)
        guard let range = focusedStatementRange, let layoutManager else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var band = NSRect.null
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragment, _, _, _, _ in
            band = band.union(fragment)
        }
        guard !band.isNull else { return }
        band.origin.x = 0
        band.size.width = bounds.width
        band = band.offsetBy(dx: 0, dy: textContainerOrigin.y)
        NSColor.controlAccentColor.withAlphaComponent(LayoutTokens.EditorGutter.statementBandOpacity).setFill()
        band.intersection(rect).fill()
    }
}
extension SQLTextView {
    /// Round 21, SK2: the selected script result's statement, a stronger band than the caret's
    /// statement so the two can be told apart.
    func drawResultStatementBand(in rect: NSRect) {
        guard let range = resultStatementRange, let layoutManager,
              NSMaxRange(range) <= (string as NSString).length else { return }
        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        var band = NSRect.null
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { fragment, _, _, _, _ in
            band = band.union(fragment)
        }
        guard !band.isNull else { return }
        band.origin.x = 0
        band.size.width = bounds.width
        band = band.offsetBy(dx: 0, dy: textContainerOrigin.y)
        NSColor.controlAccentColor.withAlphaComponent(LayoutTokens.EditorGutter.statementBandOpacity * 2).setFill()
        band.intersection(rect).fill()
    }
}
#endif
