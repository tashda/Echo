#if DEBUG
import AppKit

/// Scripted typing into the active tab's SQL editor, one character at a time through the same
/// `insertText` a key press reaches, so editing, highlighting and completion can be traced.
///
///     { "action": "type", "target": "SELECT * FROM Sales.", "seconds": 0.12 }
///
/// `seconds` is the pause between characters. Each character is a point of interest named `key`.
extension AppDirector {
    func performAutomationTyping(_ text: String, interval: Double) async {
        guard let root = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace })?.contentView,
              let textView = visibleSQLTextView(in: root) else { return }
        textView.window?.makeFirstResponder(textView)
        for character in text {
            Self.markAutomationEvent(String(character))
            textView.insertText(String(character), replacementRange: textView.selectedRange())
            try? await Task.sleep(for: .seconds(interval))
        }
    }

    /// Puts `lines` statements into the active editor in one edit, so typing can be traced in a large script.
    ///
    ///     { "action": "fill", "target": "3000" }
    func performAutomationFill(lines: Int) {
        guard let root = NSApp.windows.first(where: { $0.identifier == AppWindowIdentifier.workspace })?.contentView,
              let textView = visibleSQLTextView(in: root) else { return }
        textView.window?.makeFirstResponder(textView)
        let script = (1...max(lines, 1)).map { "SELECT \($0) AS id, 'row \($0)' AS label FROM dbo.example WHERE flag = \($0 % 2);" }
            .joined(separator: "\n")
        textView.insertText(script, replacementRange: NSRange(location: 0, length: (textView.string as NSString).length))
        textView.setSelectedRange(NSRange(location: (textView.string as NSString).length, length: 0))
    }

    private func visibleSQLTextView(in view: NSView) -> SQLTextView? {
        if let textView = view as? SQLTextView, !textView.isHiddenOrHasHiddenAncestor, textView.visibleRect.width > 0 {
            return textView
        }
        for subview in view.subviews {
            if let found = visibleSQLTextView(in: subview) { return found }
        }
        return nil
    }
}
#endif
