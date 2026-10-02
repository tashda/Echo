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
    /// The gutter's Run arrow on the statement at the caret (QE1).
    var onRunStatement: () -> Void = {}
    /// QE2: rows and time (or the error) at the end of what last ran.
    var runNotes: [QueryRunNote]
    var runningRange: NSRange?
    /// Round 21 EM5 / round 22 ED1: where the last run's error is.
    var errorMark: QueryErrorMark?
    /// Round 21, SK2: the selected script result's statement, drawn as a band.
    var resultStatementRange: NSRange?
    var onZoomStep: (Int) -> Void = { _ in }
    var completionContext: SQLEditorCompletionContext?
    var ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration?
    var onSchemaLoadNeeded: ((String) -> Void)?
    var validationRequestGeneration: Int = 0
    var editorLineRequest: EditorLineRequest?
    var editorInsertRequest: EditorInsertRequest?
    /// False while its tab is kept mounted but not shown (`KeptAliveTabsView`).
    var isActiveTab = true

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
        textView.refreshStatements()
        textView.reapplyHighlighting()
        textView.completionContext = completionContext
        if let ruleTraceConfig {
            textView.isRuleTracingEnabled = ruleTraceConfig.isEnabled
            textView.onRuleTrace = ruleTraceConfig.onTrace
        } else {
            textView.isRuleTracingEnabled = false
            textView.onRuleTrace = nil
        }
        textView.onSchemaLoadNeeded = onSchemaLoadNeeded
        context.coordinator.textView = textView

        Task { @MainActor [weak textView, weak scrollView] in
            guard let tv = textView else { return }
            scrollView?.window?.makeFirstResponder(tv)
        }
        return scrollView
    }

    func updateNSView(_ nsView: SQLScrollView, context: Context) {
        nsView.setFooterOverlay(height: context.environment.cardFooterOverlayHeight)
        if nsView.sqlTextView.runNotes != runNotes { nsView.sqlTextView.runNotes = runNotes }
        if nsView.sqlTextView.runningRange != runningRange { nsView.sqlTextView.runningRange = runningRange }
        if nsView.sqlTextView.errorMark != errorMark { nsView.sqlTextView.errorMark = errorMark }
        if nsView.sqlTextView.resultStatementRange != resultStatementRange { nsView.sqlTextView.resultStatementRange = resultStatementRange }
        nsView.sqlTextView.onZoomStep = onZoomStep
        // A kept-alive tab coming back takes the keyboard again (KeptAliveTabsView).
        if isActiveTab && !context.coordinator.wasActiveTab, let textView = context.coordinator.textView {
            Task { @MainActor [weak textView] in
                guard let textView else { return }
                textView.window?.makeFirstResponder(textView)
            }
        }
        context.coordinator.wasActiveTab = isActiveTab
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
        textView.onSchemaLoadNeeded = onSchemaLoadNeeded

        if validationRequestGeneration != context.coordinator.lastValidationGeneration {
            context.coordinator.lastValidationGeneration = validationRequestGeneration
            textView.validateNow()
        }

        if let request = editorLineRequest, request != context.coordinator.lastLineRequest {
            context.coordinator.lastLineRequest = request
            Task { @MainActor [weak textView] in
                guard let textView else { return }
                textView.goToLine(request.line)
                if let range = request.range, NSMaxRange(range) <= (textView.string as NSString).length {
                    textView.setSelectedRange(range)
                    textView.scrollRangeToVisible(range)
                }
                textView.window?.makeFirstResponder(textView)
            }
        }

        if let request = editorInsertRequest, request != context.coordinator.lastInsertRequest {
            context.coordinator.lastInsertRequest = request
            Task { @MainActor [weak textView] in
                guard let textView else { return }
                // Through shouldChangeText/didChangeText, so it is one undoable edit and the
                // binding hears about it like typing.
                let range = textView.selectedRange()
                if textView.shouldChangeText(in: range, replacementString: request.text) {
                    textView.replaceCharacters(in: range, with: request.text)
                    textView.didChangeText()
                    let caret = NSRange(location: range.location + (request.text as NSString).length, length: 0)
                    textView.setSelectedRange(caret)
                    textView.scrollRangeToVisible(caret)
                }
                textView.window?.makeFirstResponder(textView)
            }
        }

        if textView.string != text {
            context.coordinator.isUpdatingFromBinding = true
            let currentSelection = textView.selectedRange()
            textView.string = text
            textView.refreshStatements()
            textView.reapplyHighlighting()
            let maxLen = (text as NSString).length
            let restored = NSRange(
                location: min(currentSelection.location, max(0, maxLen)),
                length: min(currentSelection.length, max(0, maxLen - min(currentSelection.location, maxLen)))
            )
            textView.setSelectedRange(restored)
            context.coordinator.isUpdatingFromBinding = false
        }

        Task { @MainActor in
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
        /// Whether this editor's tab was the one on screen at the last update.
        var wasActiveTab = true
        var theme: SQLEditorTheme
        var isUpdatingFromBinding = false
        var lastValidationGeneration = 0
        var lastLineRequest: EditorLineRequest?
        var lastInsertRequest: EditorInsertRequest?

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

        func sqlTextViewDidRequestRunStatement(_ view: SQLTextView) {
            parent.onRunStatement()
        }
    }
}

protocol SQLTextViewDelegate: AnyObject {
    func sqlTextView(_ view: SQLTextView, didUpdateText text: String)
    func sqlTextView(_ view: SQLTextView, didChangeSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection)
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String)
    func sqlTextViewDidRequestRunStatement(_ view: SQLTextView)
}

extension SQLTextViewDelegate {
    func sqlTextView(_ view: SQLTextView, didPreviewSelection selection: SQLEditorSelection) {}
    func sqlTextView(_ view: SQLTextView, didRequestBookmarkWithContent content: String) {}
    func sqlTextViewDidRequestRunStatement(_ view: SQLTextView) {}
}
#endif
