#if os(macOS)
import EchoSense
import AppKit

/// QE1 (design board, 2026-09-30): when a script holds more than one statement, the statement at
/// the caret is marked and gets a Run arrow in the gutter that runs only it. Round 28.4: the mark
/// is a bracket beside the line numbers (the text is no longer tinted), and a selected script
/// result's statement (round 21, SK2) gets the same bracket, solid. Round 28.3: no current-line band.
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
        lineNumberRuler?.statementLines = focused.flatMap(lines(of:))
        lineNumberRuler?.onRunStatement = { [weak self] in
            guard let self else { return }
            self.sqlDelegate?.sqlTextViewDidRequestRunStatement(self)
        }
    }

    /// Round 21, SK2: the selected script result's statement, shown as a solid bracket.
    func updateResultStatement() {
        lineNumberRuler?.resultStatementLines = resultStatementRange.flatMap(lines(of:))
    }

    /// Round 28.7: the running statement's bracket breathes; when it ends, a line marks what ran.
    func updateRunningMark(previous: NSRange?) {
        lineNumberRuler?.setRunning(runningRange.flatMap(lines(of:)))
    }

    /// The first and last line a range of the script covers.
    func lines(of range: NSRange) -> ClosedRange<Int>? {
        let text = string as NSString
        guard range.location != NSNotFound, NSMaxRange(range) <= text.length else { return nil }
        let first = text.lineNumber(at: range.location)
        let last = text.lineNumber(at: max(NSMaxRange(range) - 1, range.location))
        return first...max(first, last)
    }
}
#endif
