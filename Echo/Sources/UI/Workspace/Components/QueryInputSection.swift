import SwiftUI
import Foundation
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

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

    private var targetTone: SQLEditorPalette.Tone {
        themeManager.effectiveColorScheme == .dark ? .dark : .light
    }

    private var editorTheme: SQLEditorTheme {
        var resolved = appState.sqlEditorTheme
        if resolved.tone != targetTone {
            resolved = SQLEditorThemeResolver.resolve(
                globalSettings: appModel.globalSettings,
                project: appModel.selectedProject,
                tone: targetTone
            )
        }
        let chrome = themeManager.activeTheme
        resolved.surfaces.background = chrome.editorBackground
        resolved.surfaces.text = chrome.editorForeground
        resolved.surfaces.gutterBackground = chrome.editorGutterBackground
        resolved.surfaces.gutterText = chrome.editorGutterForeground
        resolved.surfaces.gutterAccent = chrome.accent ?? chrome.editorForeground
        resolved.surfaces.selection = chrome.editorSelection
        resolved.surfaces.currentLine = chrome.editorCurrentLine
        if let strong = chrome.editorSymbolHighlightStrong {
            resolved.surfaces.symbolHighlightStrong = strong
        }
        if let bright = chrome.editorSymbolHighlightBright {
            resolved.surfaces.symbolHighlightBright = bright
        }
#if DEBUG
        logEditorThemeDiagnostics(resolved: resolved, chrome: chrome)
#endif
        return resolved
    }

    private var workspaceBackground: Color {
        themeManager.activeTheme.windowBackground.color
    }

    @State private var currentSelection = SQLEditorSelection(
        selectedText: "",
        range: NSRange(location: 0, length: 0),
        lineRange: nil
    )
    @State private var isSelectionActive = false

    private var hasExecutableSelection: Bool { isSelectionActive }

    private var isRunDisabled: Bool { trimmedSQL.isEmpty }

    private var trimmedSQL: String {
        query.sql.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @State private var isFormatting = false

    private let horizontalPadding: CGFloat = 20
    private let verticalPadding: CGFloat = 24

    var body: some View {
        let resolvedTheme = editorTheme
        let editorSurface = resolvedTheme.surfaces.background.color
        let workspace = workspaceBackground

        return ZStack(alignment: .bottomTrailing) {
            SQLEditorView(
                text: $query.sql,
                theme: resolvedTheme,
                display: appState.sqlEditorDisplay,
                backgroundColor: editorSurface,
                underlayColor: workspace,
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
            .padding(.horizontal, horizontalPadding)
            .padding(.top, verticalPadding)
            .padding(.bottom, verticalPadding)

            floatingControls
                .padding(.trailing, horizontalPadding)
                .padding(.bottom, verticalPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(workspace)
    }

    private var runButton: some View {
        Button(action: query.isExecuting ? onCancel : triggerExecution) {
            HStack(spacing: 10) {
                Image(systemName: currentRunIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))

                runButtonLabel
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                        .fill(
                                query.isExecuting
                                    ? Color.red.opacity(0.12)
                                    : (isSelectionActive ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(runButtonBorderColor, lineWidth: 1)
            )
            .foregroundStyle(runButtonForeground)
            .scaleEffect(query.isExecuting ? 1.0 : (isSelectionActive ? 1.03 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelectionActive)
            .animation(.easeInOut(duration: 0.2), value: query.isExecuting)
            .accessibilityLabel(query.isExecuting ? "Cancel" : (isSelectionActive ? "Run selection" : "Run"))
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!query.isExecuting && isRunDisabled)
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
        .opacity(!query.isExecuting && isRunDisabled ? 0.55 : 1)
    }

    private var formatButton: some View {
        Button(action: formatQuery) {
            Group {
                if isFormatting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .padding(8)
            .background(.ultraThinMaterial, in: Circle())
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .buttonStyle(.plain)
        .disabled(isFormatting || query.sql.isEmpty)
        .help("Format SQL (⇧⌘F)")
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    private var floatingControls: some View {
        HStack(spacing: 14) {
            formatButton
            runButton
        }
    }

    private var runButtonLabel: some View {
        Group {
            if query.isExecuting {
                Text("Cancel")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } else {
                HStack(spacing: 0) {
                    Text("Run")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    if isSelectionActive {
                        Text(" selection")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSelectionActive)
    }

    private func triggerExecution() {
        guard !isRunDisabled else { return }
        let sqlToRun: String = hasExecutableSelection ? currentSelection.selectedText : query.sql
        Task { await onExecute(sqlToRun) }
    }

    private func handleSelectionChange(_ selection: SQLEditorSelection) {
        currentSelection = selection
        let trimmed = selection.selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasSelection = !trimmed.isEmpty
        if hasSelection != isSelectionActive {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isSelectionActive = hasSelection
            }
        }
    }

    private var currentRunIcon: String {
        if query.isExecuting { return "stop.circle.fill" }
        return isSelectionActive ? "play.rectangle" : "play.fill"
    }

    private var runButtonBorderColor: Color {
        if query.isExecuting { return Color.red.opacity(0.7) }
        return isSelectionActive ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.35)
    }

    private var runButtonForeground: Color {
        query.isExecuting ? Color.red.opacity(0.95) : Color.accentColor
    }

    private func formatQuery() {
        guard !query.sql.isEmpty, !isFormatting else { return }
        isFormatting = true
        let currentSQL = query.sql
        Task {
            do {
                let formatted = try await SQLFormatterService.shared.format(sql: currentSQL)
                await MainActor.run { query.sql = formatted }
            } catch {
                await MainActor.run {
                    appState.showError(.queryError(error.localizedDescription))
                }
            }
            await MainActor.run { isFormatting = false }
        }
    }
}

#if DEBUG
private extension QueryInputSection {
    func logEditorThemeDiagnostics(resolved: SQLEditorTheme, chrome: AppColorTheme) {
        let window = describeColor(chrome.windowBackground)
        let surface = describeColor(chrome.surfaceBackground)
        let editorBG = describeColor(resolved.surfaces.background)
        let paletteBG = describeColor(appState.sqlEditorTheme.surfaces.background)
        print("[QueryInputSection] tone=\(resolved.tone) window=\(window) surface=\(surface) resolvedEditor=\(editorBG) originalPalette=\(paletteBG)")
    }

    func describeColor(_ color: ColorRepresentable) -> String {
        String(format: "r%.2f g%.2f b%.2f a%.2f", color.red, color.green, color.blue, color.alpha)
    }
}
#endif
