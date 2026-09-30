#if os(macOS)
import AppKit

/// QE1 (design board, 2026-09-30): when a script holds more than one statement, the statement at
/// the caret gets a faint band behind it and a Run arrow in the gutter that runs only it.
extension SQLTextView {
    func refreshStatements() {
        cachedStatements = displayOptions.statementFocusEnabled ? SQLStatementAtCaret.statements(in: string) : []
        updateStatementFocus()
    }

    func updateStatementFocus() {
        let caret = selectedRange().location
        let focused: NSRange? = cachedStatements.count > 1 && caret != NSNotFound
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

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
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
#endif
