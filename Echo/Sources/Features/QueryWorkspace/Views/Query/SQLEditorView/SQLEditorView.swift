import SwiftUI
import Combine
import Foundation
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SQLEditorView: View {
    @Binding var text: String
    var theme: SQLEditorTheme
    var display: SQLEditorDisplayOptions
    var backgroundColor: Color?
    var completionContext: SQLEditorCompletionContext?
    var ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration?
    var onSchemaLoadNeeded: ((String) -> Void)?
    var onTextChange: (String) -> Void
    var onSelectionChange: (SQLEditorSelection) -> Void
    var onSelectionPreviewChange: (SQLEditorSelection) -> Void
    var clipboardMetadata: ClipboardHistoryStore.Entry.Metadata
    var onAddBookmark: (String) -> Void

    @Environment(ClipboardHistoryStore.self) private var clipboardHistory

    init(
        text: Binding<String>,
        theme: SQLEditorTheme,
        display: SQLEditorDisplayOptions,
        backgroundColor: Color? = nil,
        completionContext: SQLEditorCompletionContext? = nil,
        ruleTraceConfig: SQLAutocompleteRuleTraceConfiguration? = nil,
        onSchemaLoadNeeded: ((String) -> Void)? = nil,
        onTextChange: @escaping (String) -> Void,
        onSelectionChange: @escaping (SQLEditorSelection) -> Void,
        onSelectionPreviewChange: @escaping (SQLEditorSelection) -> Void,
        clipboardMetadata: ClipboardHistoryStore.Entry.Metadata = .empty,
        onAddBookmark: @escaping (String) -> Void = { _ in }
    ) {
        _text = text
        self.theme = theme
        self.display = display
        self.backgroundColor = backgroundColor
        self.completionContext = completionContext
        self.ruleTraceConfig = ruleTraceConfig
        self.onSchemaLoadNeeded = onSchemaLoadNeeded
        self.onTextChange = onTextChange
        self.onSelectionChange = onSelectionChange
        self.onSelectionPreviewChange = onSelectionPreviewChange
        self.clipboardMetadata = clipboardMetadata
        self.onAddBookmark = onAddBookmark
    }

    var body: some View {
#if os(macOS)
        MacSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext,
            ruleTraceConfig: ruleTraceConfig,
            onSchemaLoadNeeded: onSchemaLoadNeeded
        )
#else
        IOSSQLEditorRepresentable(
            text: $text,
            theme: theme,
            display: display,
            backgroundColor: backgroundColor,
            onTextChange: onTextChange,
            onSelectionChange: onSelectionChange,
            onSelectionPreviewChange: onSelectionPreviewChange,
            clipboardHistory: clipboardHistory,
            clipboardMetadata: clipboardMetadata,
            onAddBookmark: onAddBookmark,
            completionContext: completionContext
        )
#endif
    }
}

#if !os(macOS)
// Simplified iOS/iPadOS implementation using UITextView
private struct IOSSQLEditorRepresentable: UIViewRepresentable {
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

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.font = theme.uiFont
        textView.textColor = theme.tokenColors.plain.uiColor
        textView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.surfaces.background.uiColor
        textView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.delegate = context.coordinator
        textView.text = text
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        textView.textContainer.widthTracksTextView = display.wrapLines
        textView.textContainer.lineFragmentPadding = 12
        let ligatureValue = theme.ligaturesEnabled ? 1 : 0
        textView.typingAttributes[.ligature] = ligatureValue
        textView.textStorage.addAttribute(.ligature, value: ligatureValue, range: NSRange(location: 0, length: textView.textStorage.length))
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        uiView.font = theme.uiFont
        uiView.textColor = theme.tokenColors.plain.uiColor
        uiView.backgroundColor = (backgroundColor.map(UIColor.init)) ?? theme.surfaces.background.uiColor
        uiView.tintColor = theme.tokenColors.operatorSymbol.uiColor
        uiView.textContainer.widthTracksTextView = display.wrapLines
        let ligatureValue = theme.ligaturesEnabled ? 1 : 0
        uiView.typingAttributes[.ligature] = ligatureValue
        uiView.textStorage.addAttribute(.ligature, value: ligatureValue, range: NSRange(location: 0, length: uiView.textStorage.length))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let parent: IOSSQLEditorRepresentable

        init(parent: IOSSQLEditorRepresentable) {
            self.parent = parent
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            let selection = textView.selectedRange
            let selected = (selection.length > 0) ? (textView.text as NSString).substring(with: selection) : ""
            let lineRange: ClosedRange<Int>? = nil
            let selectionInfo = SQLEditorSelection(selectedText: selected, range: selection, lineRange: lineRange)
            parent.onSelectionPreviewChange(selectionInfo)
            parent.onSelectionChange(selectionInfo)
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange(textView.text)
            textViewDidChangeSelection(textView)
        }
    }
}
#endif
