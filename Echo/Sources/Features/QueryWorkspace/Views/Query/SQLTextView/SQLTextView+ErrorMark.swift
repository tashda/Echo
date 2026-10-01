#if os(macOS)
import AppKit

/// Round 21 EM5 and round 22 ED1: the last run's error is marked on the word (a whole line when
/// SQL Server names no object), with a Fix when the server's hint or the table's columns name the
/// right word (EH3). Round 28.6: the mark is the same tinted pill as a mistake found while typing
/// (E10, SL0), and its glass bubble opens on hover or with the caret on its line (BB3, M3).
extension SQLTextView {
    func showErrorMark() {
        errorMarkView?.removeFromSuperview()
        errorMarkView = nil
        guard let mark = errorMark, let frame = errorPillRect(for: mark.range) else { return }
        let content = ErrorBubbleContent(title: "Error", message: mark.message, detail: mark.detail, fix: mark.fix)
        let view = ErrorPillView(content: content, line: mark.line, fill: markColor(.wrong, .strong), corners: displayOptions.markCorners) { [weak self] fix in
            self?.applyErrorFix(fix, at: mark.range)
        }
        view.frame = frame
        addSubview(view)
        errorMarkView = view
        updateErrorBubbles()
    }

    /// EH3: replaces the marked word; undoable like typing. The edit clears the mark (EC3).
    func applyErrorFix(_ fix: QueryErrorMark.Fix, at range: NSRange) {
        guard NSMaxRange(range) <= (string as NSString).length,
              shouldChangeText(in: range, replacementString: fix.replacement) else { return }
        textStorage?.replaceCharacters(in: range, with: fix.replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (fix.replacement as NSString).length, length: 0))
        window?.makeFirstResponder(self)
    }

    /// The mistake's mark on its first line, in the marks' language (round 28.15).
    func errorPillRect(for range: NSRange) -> NSRect? {
        markRects(for: range).first
    }

    /// M3: the bubble of every mark on the caret's line is open; the others close.
    func updateErrorBubbles() {
        let caret = selectedRange()
        let caretLine = caret.location == NSNotFound ? nil : (string as NSString).lineNumber(at: caret.location)
        let pills = validationOverlays.compactMap { $0 as? ErrorPillView } + [errorMarkView].compactMap { $0 }
        for pill in pills { pill.isCaretOnLine = caret.length == 0 && pill.line == caretLine }
    }

    /// T1: the live check runs when the caret leaves the line that was edited (or after a pause).
    func checkLineLeft() {
        let caret = selectedRange().location
        guard let edited = lastEditedLine, caret != NSNotFound else { return }
        let line = (string as NSString).lineNumber(at: caret)
        guard line != edited else { return }
        lastEditedLine = nil
        if displayOptions.liveValidationEnabled { validateNow() }
    }
}
#endif
