import AppKit

/// Text that comes from outside the editor (a column from the Explorer's menu), put where the
/// caret is, in the query tab that is showing.
extension SQLTextView {
    /// The editor of the tab on screen in the key window, if a query tab is open.
    static func visibleEditor(in window: NSWindow?) -> SQLTextView? {
        guard let content = window?.contentView else { return nil }
        return findVisible(in: content)
    }

    private static func findVisible(in view: NSView) -> SQLTextView? {
        if let editor = view as? SQLTextView, !editor.isHiddenOrHasHiddenAncestor { return editor }
        for subview in view.subviews {
            if let found = findVisible(in: subview) { return found }
        }
        return nil
    }

    /// Replaces the selection with `text` as one undoable edit, without opening completions.
    func insertExternally(_ text: String) {
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: text) else { return }
        replaceCharacters(in: range, with: text)
        didChangeText()
        window?.makeFirstResponder(self)
    }
}
