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
        guard let view = scroll.documentView as? NSTextView, view.string != text else { return }
        view.string = text
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: LabCaretTextView
        init(_ parent: LabCaretTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.text = view.string
            parent.caret = view.selectedRange().location
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            parent.caret = view.selectedRange().location
        }
    }
}
