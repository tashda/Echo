import SwiftUI
#if !os(macOS)
import UIKit
#endif

struct QueryInputSection: View {
    @ObservedObject var tab: QueryTab
    let onExecute: (String) async -> Void
    let onCancel: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var currentSelection = SQLEditorSelection(
        selectedText: "",
        range: NSRange(location: 0, length: 0),
        lineRange: nil
    )
    @State private var isSelectionActive = false

    private var hasExecutableSelection: Bool {
        return isSelectionActive
    }

    private var isRunDisabled: Bool {
        trimmedSQL.isEmpty
    }

    private var trimmedSQL: String {
        tab.sql.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var editorBackground: Color {
#if os(macOS)
        return Color(nsColor: .textBackgroundColor)
#else
        return Color(UIColor.systemBackground)
#endif
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 72)

            floatingRunButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(editorBackground)
    }

    private var editor: some View {
        SQLEditorView(
            text: $tab.sql,
            theme: appState.sqlEditorTheme,
            onSelectionChange: handleSelectionChange,
            onSelectionPreviewChange: handleSelectionChange
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .layoutPriority(1)
        .background(editorBackground)
        .contentShape(Rectangle())
    }

    private var floatingRunButton: some View {
        Button(action: tab.isExecuting ? onCancel : triggerExecution) {
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
                                tab.isExecuting
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
            .scaleEffect(tab.isExecuting ? 1.0 : (isSelectionActive ? 1.03 : 1.0))
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSelectionActive)
            .animation(.easeInOut(duration: 0.2), value: tab.isExecuting)
            .accessibilityLabel(tab.isExecuting ? "Cancel" : (isSelectionActive ? "Run selection" : "Run"))
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!tab.isExecuting && isRunDisabled)
        .buttonStyle(.plain)
        .padding(24)
        .shadow(color: Color.black.opacity(0.12), radius: 18, y: 12)
        .opacity(!tab.isExecuting && isRunDisabled ? 0.55 : 1)
        .zIndex(2)
    }

    private func triggerExecution() {
        guard !isRunDisabled else { return }
        let sqlToRun: String
        if hasExecutableSelection {
            sqlToRun = currentSelection.selectedText
        } else {
            sqlToRun = tab.sql
        }

        Task {
            await onExecute(sqlToRun)
        }
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
        if tab.isExecuting { return "stop.circle.fill" }
        return isSelectionActive ? "play.rectangle" : "play.fill"
    }

    private var runButtonBorderColor: Color {
        if tab.isExecuting { return Color.red.opacity(0.7) }
        return isSelectionActive ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.35)
    }

    private var runButtonForeground: Color {
        if tab.isExecuting { return Color.red.opacity(0.95) }
        return Color.accentColor
    }

    private var runButtonLabel: some View {
        Group {
            if tab.isExecuting {
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
}
