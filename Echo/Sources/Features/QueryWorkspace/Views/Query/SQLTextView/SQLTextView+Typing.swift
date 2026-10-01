#if os(macOS)
import AppKit

/// Round 28.9: Tab, ⇧Tab, Return, closing brackets and quotes, and ⌘/, applied to the text view
/// with undo. The rules are in `SQLEditorTyping`.
extension SQLTextView {
    override func insertTab(_ sender: Any?) {
        let selection = selectedRange()
        if spansLines(selection) {
            replaceSelectedLines(with: SQLEditorTyping.indented)
        } else {
            insertText(SQLEditorTyping.softTab(atColumn: column(of: selection.location)), replacementRange: selection)
        }
    }

    override func insertBacktab(_ sender: Any?) {
        replaceSelectedLines(with: SQLEditorTyping.outdented)
    }

    override func insertNewline(_ sender: Any?) {
        let text = string as NSString
        let caret = selectedRange().location
        let line = text.substring(with: text.lineRange(for: NSRange(location: caret, length: 0)))
        let indent = SQLEditorTyping.leadingWhitespace(of: line)
        let room = min(indent.count, max(caret - text.lineRange(for: NSRange(location: caret, length: 0)).location, 0))
        insertText("\n" + String(indent.prefix(room)), replacementRange: selectedRange())
    }

    /// Handles a typed opener or closer; true when the text view should not insert it itself.
    func handleTypedPair(_ typed: String, replacementRange: NSRange) -> Bool {
        let selection = selectedRange()
        guard selection.length == 0, replacementRange.location == NSNotFound || replacementRange == selection else { return false }
        let text = string as NSString
        let next = selection.location < text.length ? Character(text.substring(with: NSRange(location: selection.location, length: 1))) : nil
        let previous = selection.location > 0 ? Character(text.substring(with: NSRange(location: selection.location - 1, length: 1))) : nil
        if SQLEditorTyping.stepsOver(typed, next: next) {
            setSelectedRange(NSRange(location: selection.location + 1, length: 0))
            if typed == ")" { flashMatchingBracket(closingAt: selection.location) }
            return true
        }
        guard let closer = SQLEditorTyping.autoCloser(for: typed, before: next, after: previous) else { return false }
        super.insertText(typed + closer, replacementRange: selection)
        setSelectedRange(NSRange(location: selection.location + (typed as NSString).length, length: 0))
        return true
    }

    /// ⌘/: comments the selected lines (or the caret's) out with `--`, or back in.
    func toggleLineComment() {
        replaceSelectedLines(with: SQLEditorTyping.toggledComment)
    }

    private func spansLines(_ range: NSRange) -> Bool {
        range.length > 0 && (string as NSString).substring(with: range).contains("\n")
    }

    private func column(of location: Int) -> Int {
        location - (string as NSString).lineRange(for: NSRange(location: location, length: 0)).location
    }

    /// Rewrites the whole lines the selection touches as one undoable change, then selects them.
    private func replaceSelectedLines(with transform: ([String]) -> [String]) {
        let text = string as NSString
        var block = text.lineRange(for: selectedRange())
        let endsWithNewline = block.length > 0 && text.substring(with: NSRange(location: NSMaxRange(block) - 1, length: 1)) == "\n"
        if endsWithNewline { block.length -= 1 }
        let lines = text.substring(with: block).components(separatedBy: "\n")
        let replacement = transform(lines).joined(separator: "\n")
        guard replacement != text.substring(with: block), shouldChangeText(in: block, replacementString: replacement) else { return }
        textStorage?.replaceCharacters(in: block, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: block.location, length: (replacement as NSString).length))
    }
}
#endif
