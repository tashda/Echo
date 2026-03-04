#if os(macOS)
import AppKit
import SwiftUI
import EchoSense

struct MacSQLEditorRepresentable: NSViewRepresentable {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardHistory: ClipboardHistoryStore
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void
    var completionContext: SQLEditorCompletionContext?
    var ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeNSView(context: Context) -> SQLScrollView {
        let scrollView = SQLScrollView(
            theme: theme,
            display: display,
            backgroundOverride: backgroundColor.map(NSColor.init),
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig
        )
        let textView = scrollView.sqlTextView
        textView.sqlDelegate = context.coordinator
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
        textView.string = text
        textView.reapplyHighlighting()
        textView.completionContext = completionContext
        if let ruleTraceConfig {
            textView.isRuleTracingEnabled = ruleTraceConfig.isEnabled
            textView.onRuleTrace = ruleTraceConfig.onTrace
        } else {
            textView.isRuleTracingEnabled = false
            textView.onRuleTrace = nil
        }
        context.coordinator.textView = textView

        DispatchQueue.main.async { [weak textView, weak scrollView] in
            guard let tv = textView else { return }
            scrollView?.window?.makeFirstResponder(tv)
        }
        return scrollView
    }

    func updateNSView(_ nsView: SQLScrollView, context: Context) {
        nsView.updateTheme(theme)
        nsView.updateDisplay(display)
        nsView.updateBackgroundOverride(backgroundColor.map(NSColor.init))
        nsView.completionContext = completionContext
        let textView = nsView.sqlTextView
        context.coordinator.theme = theme
        context.coordinator.parent = self
        textView.clipboardHistory = clipboardHistory
        textView.clipboardMetadata = clipboardMetadata
        if let ruleTraceConfig {
            textView.isRuleTracingEnabled = ruleTraceConfig.isEnabled
            textView.onRuleTrace = ruleTraceConfig.onTrace
        } else {
            textView.isRuleTracingEnabled = false
            textView.onRuleTrace = nil
        }

        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            let currentSelection = textView.selectedRange()
            textView.string = text
            textView.reapplyHighlighting()
            let maxLen = (text as NSString).length
            let restored = NSRange(
                location: min(currentSelection.location, max(0, maxLen)),
                length: min(currentSelection.length, max(0, maxLen - min(currentSelection.location, maxLen)))
            )
            textView.setSelectedRange(restored)
            context.coordinator.isUpdatingFromBinding = false
        }

        DispatchQueue.main.async {
            let scrollViewWidth = nsView.bounds.width
            let rulerWidth = nsView.verticalRulerView?.ruleThickness ?? 0
            let availableWidth = max(scrollViewWidth - rulerWidth, 320)

            if let textContainer = textView.textContainer {
                if nsView.currentDisplayOptions.wrapLines {
                    if textContainer.size.width != availableWidth {
                        textContainer.size = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
                    }
                } else {
                    textContainer.size = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                }
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, SQLTextViewDelegate {
        var parent: MacSQLEditorRepresentable
        weak var textView: SQLTextView?
        var theme: SQLEditorTheme
        var isUpdatingFromBinding = false

        init(parent: MacSQLEditorRepresentable) {
            self.parent = parent
            self.theme = parent.theme
        }

        func sqlTextView(_ view: SQLTextView, didUpdateText text: String) {
            guard !isUpdatingFromBinding else { return }
            parent.text = text
            parent.onTextChange(text)
        }

        func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection) {
            parent.onSelectionChange(selection)
        }

        func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {
            parent.onSelectionPreviewChange(selection)
        }

        func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {
            parent.onAddBookmark(content)
        }
    }
}

protocol SQLTextViewDelegate: AnyObject {
    func sqlTextView(_ view: SQLTextView, didUpdateText text: String)
    func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String)
}

extension SQLTextViewDelegate {
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {}
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {}
}
#endif
