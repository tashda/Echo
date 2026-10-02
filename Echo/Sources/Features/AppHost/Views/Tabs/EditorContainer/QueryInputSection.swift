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
    var onRunStatement: () -> Void = {}

    @Environment(AppState.self) var appState
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppearanceStore.self) private var appearanceStore
    @Environment(\.cardFooterRestsInCard) private var footerRestsInCard
    @Environment(\.cardFooterOverlayHeight) private var footerOverlayHeight
    @Environment(\.cardHiddenBottom) private var cardHiddenBottom
    @Environment(\.echoMotion) private var motion
    private let sqlHelpProvider = SQLHelpInspectorContentProvider()

    /// The editor's theme at this tab's zoom (round 28.8).
    private var editorTheme: SQLEditorTheme {
        var theme = appState.sqlEditorTheme
        theme.fontSize *= query.editorZoom
        return theme
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

    /// Round 28.14: the gutter starts at the card's edge, as Echo Labs draws it, so a lane can
    /// centre its numbers without meeting the error dot.
    private let leadingPadding: CGFloat = SpacingTokens.none
    private let trailingPadding: CGFloat = SpacingTokens.md1
    private let topPadding: CGFloat = 0
    /// The text runs to the card's edge, under the bottom's material (owner, after round 44);
    /// the footer's room keeps the last line above the pills, as in the results grid.
    private let bottomPadding: CGFloat = SpacingTokens.none
    private let footerRoom = LayoutTokens.Footer.height + LayoutTokens.Footer.bottomLift

    var body: some View {
        let resolvedTheme = editorTheme

        return SQLEditorView(
            text: $query.sql,
            theme: resolvedTheme,
            display: appState.sqlEditorDisplay,
            backgroundColor: editorBackground,
            completionContext: completionContext,
            onSchemaLoadNeeded: onSchemaLoadNeeded,
            validationRequestGeneration: query.validationRequestGeneration,
            editorLineRequest: query.editorLineRequest,
            editorInsertRequest: query.editorInsertRequest,
            onTextChange: { newText in
                if query.sql != newText {
                    query.sql = newText
                    query.runNote = nil
                    query.errorMark = nil
                    query.highlightedStatementRange = nil
                }
            },
            onSelectionChange: handleSelectionChange,
            onSelectionPreviewChange: handleSelectionChange,
            clipboardMetadata: query.clipboardMetadata,
            onAddBookmark: onAddBookmark,
            onRunStatement: onRunStatement,
            runNotes: query.runNotes,
            runningRange: query.isExecuting ? query.lastRunRange : nil,
            errorMark: query.errorMark,
            resultStatementRange: query.highlightedStatementRange,
            onZoomStep: { query.editorZoom = EditorZoom.step(query.editorZoom, by: $0) }
        )
        .environment(\.cardFooterOverlayHeight, footerRoom)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.top, topPadding)
        .padding(.bottom, bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            // With the results in their own card, the editor's bottom softens as theirs does
            // (owner, after round 44); without them the footer brings its own.
            if footerOverlayHeight == 0 {
                FooterMaterialBlur()
                    .padding(.bottom, cardHiddenBottom)
            }
        }
        .overlay(alignment: .bottomLeading) {
            EditorZoomControl(zoom: $query.editorZoom)
                .padding(.leading, EditorZoomControl.leadingInset)
                .padding(.bottom, zoomBottomInset)
                // It chases the results card's edge a moment later and lands with a small bounce.
                .animation(motion.liquidTrail, value: zoomBottomInset)
        }
        .background(alignment: .leading) {
            if appState.sqlEditorDisplay.showLineNumbers {
                EditorGutterSurface(style: appState.sqlEditorDisplay.gutterStyle, width: gutterSurfaceWidth,
                                    fill: resolvedTheme.surfaces.gutterBackground.color)
            }
        }
        .background(editorBackground)
    }

    private var zoomBottomInset: CGFloat {
        EditorZoomControl.bottomInset(footerInCard: footerRestsInCard, hiddenBelow: cardHiddenBottom)
    }

    /// The editor's padding plus the gutter, sized as LineNumberRulerView sizes itself.
    private var gutterSurfaceWidth: CGFloat {
        let lines = query.sql.utf8.reduce(1) { $1 == UInt8(ascii: "\n") ? $0 + 1 : $0 }
        let digits = max(String(lines).count, LayoutTokens.EditorGutter.minimumDigits)
        return leadingPadding + LineNumberRulerView.thickness(forDigits: digits, codeSize: editorTheme.fontSize)
    }

    func handleSelectionChange(_ selection: SQLEditorSelection) {
        let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSelection = !trimmed.isEmpty
        Task {
            currentSelection = selection
            query.selectedText = selection.selectedText
            query.caretLocation = selection.range.location
            query.selectionRange = selection.range
            // Always sync to QueryEditorState so toolbar stays correct
            query.hasActiveSelection = hasSelection
            syncSQLHelpInspector(using: trimmed)
            guard hasSelection != isSelectionActive else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isSelectionActive = hasSelection
            }
        }
    }

    private func syncSQLHelpInspector(using trimmedSelection: String) {
        let provider = sqlHelpProvider
        let databaseType = completionContext?.databaseType ?? .postgresql

        if let content = provider.content(for: trimmedSelection, databaseType: databaseType) {
            if case .sqlHelp = environmentState.dataInspectorContent {
                environmentState.dataInspectorContent = .sqlHelp(content)
            }
        } else if case .sqlHelp = environmentState.dataInspectorContent,
                  appState.showInfoSidebar {
            environmentState.dataInspectorContent = nil
        }
    }
}
