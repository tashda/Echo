import SwiftUI

extension QueryInputSection {
    var runButton: some View {
        Button(action: query.isExecuting ? onCancel : triggerExecution) {
            HStack(spacing: 10) {
                Image(systemName: currentRunIcon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))

                runButtonLabel
            }
            .padding(.horizontal, 18)
            .padding(.vertical, SpacingTokens.xs2)
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
            .accessibilityIdentifier("run-query-button")
        }
        .keyboardShortcut(.return, modifiers: [.command])
        .disabled(!query.isExecuting && isRunDisabled)
        .buttonStyle(.plain)
        .shadow(color: Color.black.opacity(0.14), radius: 12, y: 6)
        .opacity(!query.isExecuting && isRunDisabled ? 0.55 : 1)
    }

    var formatButton: some View {
        Button(action: formatQuery) {
            Group {
                if isFormatting {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "wand.and.stars")
                        .font(TypographyTokens.caption2.weight(.semibold))
                }
            }
            .padding(SpacingTokens.xs)
            .background(.ultraThinMaterial, in: Circle())
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .buttonStyle(.plain)
        .disabled(isFormatting || query.sql.isEmpty)
        .help("Format SQL (Shift+Cmd+F)")
        .accessibilityIdentifier("format-query-button")
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    var floatingControls: some View {
        HStack(spacing: 14) {
            formatButton
            runButton
        }
    }

    var runButtonLabel: some View {
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

    func triggerExecution() {
        guard !isRunDisabled else { return }
        let sqlToRun: String = hasExecutableSelection ? currentSelection.selectedText : query.sql
        Task { await onExecute(sqlToRun) }
    }

    var currentRunIcon: String {
        if query.isExecuting { return "stop.circle.fill" }
        return isSelectionActive ? "play.rectangle" : "play.fill"
    }

    var runButtonBorderColor: Color {
        if query.isExecuting { return Color.red.opacity(0.7) }
        return isSelectionActive ? Color.accentColor.opacity(0.55) : Color.white.opacity(0.35)
    }

    var runButtonForeground: Color {
        query.isExecuting ? Color.red.opacity(0.95) : Color.accentColor
    }

    func formatQuery() {
        guard !query.sql.isEmpty, !isFormatting else { return }
        isFormatting = true
        let currentSQL = query.sql
        let dialect = formatterDialect
        Task {
            do {
                let formatted = try await SQLFormatterService.shared.format(sql: currentSQL, dialect: dialect)
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
