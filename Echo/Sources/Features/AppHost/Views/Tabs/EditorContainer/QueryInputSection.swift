import SwiftUI
import Foundation
import EchoSense
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct QueryInputSection: View {
    @ObservedObject var query: QueryEditorState
    let onExecute: (String) async -> Void
    let onCancel: () -> Void
    let onAddBookmark: (String) -> Void
    let completionContext: SQLEditorCompletionContext?

    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var environmentState: EnvironmentState
    @EnvironmentObject private var appearanceStore: AppearanceStore

    private var targetTone: SQLEditorPalette.Tone {
        appearanceStore.effectiveColorScheme == .dark ? .dark : .light
    }

    private var editorTheme: SQLEditorTheme {
        appState.sqlEditorTheme
    }

    private var editorBackground: Color {
        ColorTokens.Background.primary
    }

    @State var currentSelection = SQLEditorSelection(
        selectedText: "",
        range: NSRange(location: 0, length: 0),
        lineRange: nil
    )
    @State var isSelectionActive = false

    var hasExecutableSelection: Bool { isSelectionActive }

    var isRunDisabled: Bool { trimmedSQL.isEmpty }

    private var trimmedSQL: String {
        query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @State var isFormatting = false

    private let leadingPadding: CGFloat = SpacingTokens.xs
    private let trailingPadding: CGFloat = SpacingTokens.md1
    private let topPadding: CGFloat = 0
    private let bottomPadding: CGFloat = SpacingTokens.md2

    var body: some View {
        let resolvedTheme = editorTheme

        return ZStack(alignment: .bottomTrailing) {
            SQLEditorView(
                text: $query.sql,
                theme: resolvedTheme,
                display: appState.sqlEditorDisplay,
                backgroundColor: editorBackground,
                completionContext: completionContext,
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

            floatingControls
                .padding(.trailing, trailingPadding)
                .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(editorBackground)
    }

    func handleSelectionChange(_ selection: SQLEditorSelection) {
        let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSelection = !trimmed.isEmpty
        DispatchQueue.main.async {
            currentSelection = selection
            guard hasSelection != isSelectionActive else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isSelectionActive = hasSelection
            }
        }
    }

    var formatterDialect: SQLFormatterService.Dialect {
        switch completionContext?.databaseType {
        case .mysql: return .mysql
        case .microsoftSQL: return .microsoftSQL
        case .sqlite: return .sqlite
        default: return .postgres
        }
    }
}
