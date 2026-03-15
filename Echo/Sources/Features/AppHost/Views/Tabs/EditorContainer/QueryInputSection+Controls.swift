import SwiftUI
import EchoSense

extension QueryInputSection {
    var runButton: some View {
        Button(action: query.isExecuting ? onCancel : triggerExecution) {
            HStack(spacing: SpacingTokens.xs2) {
                Image(systemName: currentRunIcon)
                    .font(TypographyTokens.standard.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .transition(.scale.combined(with: .opacity))

                runButtonLabel
            }
            .padding(.horizontal, SpacingTokens.md2)
            .padding(.vertical, SpacingTokens.xs2)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                        .fill(
                                query.isExecuting
                                    ? ColorTokens.Status.error.opacity(0.12)
                                    : (isSelectionActive ? ColorTokens.accent.opacity(0.12) : Color.clear)
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

    var estimatedPlanButton: some View {
        Button(action: triggerEstimatedPlan) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(TypographyTokens.caption2.weight(.semibold))
                .padding(SpacingTokens.xs)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(isRunDisabled || query.isExecuting || query.isLoadingExecutionPlan || onRequestEstimatedPlan == nil)
        .opacity(onRequestEstimatedPlan == nil ? 0 : 1)
        .help("Display Estimated Execution Plan (Ctrl+Cmd+E)")
        .accessibilityIdentifier("estimated-plan-button")
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    func triggerEstimatedPlan() {
        guard let handler = onRequestEstimatedPlan, !isRunDisabled else { return }
        let sqlToRun: String = hasExecutableSelection ? currentSelection.selectedText : query.sql
        Task { await handler(sqlToRun) }
    }

    var statisticsToggle: some View {
        let isActive = query.statisticsEnabled
        return Button {
            query.statisticsEnabled.toggle()
        } label: {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(TypographyTokens.caption2.weight(.semibold))
                .padding(SpacingTokens.xs)
                .background(
                    isActive
                        ? AnyShapeStyle(ColorTokens.accent.opacity(0.18))
                        : AnyShapeStyle(.ultraThinMaterial),
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(isActive ? ColorTokens.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(isActive ? "Disable Statistics IO/TIME" : "Enable Statistics IO/TIME")
        .accessibilityIdentifier("statistics-toggle-button")
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 3)
    }

    private var isMSSQLConnection: Bool {
        completionContext?.databaseType == .microsoftSQL
    }

    var floatingControls: some View {
        HStack(spacing: SpacingTokens.sm2) {
            if isMSSQLConnection {
                statisticsToggle
            }
            estimatedPlanButton
            formatButton
            runButton
        }
    }

    var runButtonLabel: some View {
        Group {
            if query.isExecuting {
                Text("Cancel")
                    .font(TypographyTokens.standard.weight(.semibold))
            } else {
                HStack(spacing: SpacingTokens.none) {
                    Text("Run")
                        .font(TypographyTokens.standard.weight(.semibold))
                    if isSelectionActive {
                        Text(" selection")
                            .font(TypographyTokens.standard.weight(.semibold))
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
        if query.isExecuting { return ColorTokens.Status.error.opacity(0.7) }
        return isSelectionActive ? ColorTokens.accent.opacity(0.55) : Color.white.opacity(0.35)
    }

    var runButtonForeground: Color {
        query.isExecuting ? ColorTokens.Status.error.opacity(0.95) : ColorTokens.accent
    }

    func formatQuery() {
        guard !query.sql.isEmpty, !isFormatting else { return }
        isFormatting = true
        let currentSQL = query.sql
        let dialect = formatterDialect
        Task {
            do {
                let formatted = try await SQLFormatter.shared.format(sql: currentSQL, dialect: dialect)
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
