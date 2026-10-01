import AppKit
import SwiftUI

/// A monospaced text editor that reports the caret position, which SwiftUI's TextEditor can't.
struct LabCaretTextView: NSViewRepresentable {
    @Binding var text: String
    @Binding var caret: Int

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.delegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.allowsUndo = true
        view.textContainerInset = NSSize(width: 8, height: 8)
        view.string = text
        view.setSelectedRange(NSRange(location: min(caret, (text as NSString).length), length: 0))
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        // Text and caret set from outside (opening a scenario) move the editor's; they are not edits,
        // so nothing is reported back while they are applied.
        context.coordinator.isMoving = true
        defer { context.coordinator.isMoving = false }
        if view.string != text { view.string = text }
        let wanted = min(max(caret, 0), (text as NSString).length)
        if view.selectedRange().location != wanted || view.selectedRange().length != 0 {
            view.setSelectedRange(NSRange(location: wanted, length: 0))
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LabCaretTextView
        /// True while the caret is being set from outside, so that isn't reported back as an edit.
        var isMoving = false
        init(_ parent: LabCaretTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard !isMoving, let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            parent.caret = view.selectedRange().location
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isMoving, let view = notification.object as? NSTextView else { return }
            parent.caret = view.selectedRange().location
        }
    }
}
