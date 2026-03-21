import SwiftUI
import Foundation
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct QueryInputSection: View {
    @Bindable var query: QueryEditorState
    let onAddBookmark: (String) -> Void
    let completionContext: SQLEditorCompletionContext?
    let onSchemaLoadNeeded: ((String) -> Void)?

    @Environment(AppState.self) var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore

    private var editorTheme: SQLEditorTheme {
        appState.sqlEditorTheme
    }

    private var editorBackground: Color {
        ColorTokens.Background.primary
    }

    @State private var currentSelection = SQLEditorSelection(
        selectedText: "",
        range: NSRange(location: 0, length: 0),
        lineRange: nil
    )
    @State private var isSelectionActive = false

    private let leadingPadding: CGFloat = SpacingTokens.xs
    private let trailingPadding: CGFloat = SpacingTokens.md1
    private let topPadding: CGFloat = 0
    private let bottomPadding: CGFloat = SpacingTokens.md2

    var body: some View {
        let resolvedTheme = editorTheme

        return SQLEditorView(
            text: $query.sql,
            theme: resolvedTheme,
            display: appState.sqlEditorDisplay,
            backgroundColor: editorBackground,
            completionContext: completionContext,
            onSchemaLoadNeeded: onSchemaLoadNeeded,
            onTextChange: { newText in
                if query.sql != newText {
                    query.sql = newText
                }
            },
            onSelectionChange: handleSelectionChange,
            onSelectionPreviewChange: handleSelectionChange,
            clipboardMetadata: query.clipboardMetadata,
            onAddBookmark: onAddBookmark
        )
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(editorBackground)
    }

    func handleSelectionChange(_ selection: SQLEditorSelection) {
        let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSelection = !trimmed.isEmpty
        Task {
            currentSelection = selection
            query.selectedText = selection.selectedText
            // Always sync to QueryEditorState so toolbar stays correct
            query.hasActiveSelection = hasSelection
            guard hasSelection != isSelectionActive else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isSelectionActive = hasSelection
            }
        }
    }

}
