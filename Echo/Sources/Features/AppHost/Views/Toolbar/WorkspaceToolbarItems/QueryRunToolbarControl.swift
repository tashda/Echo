import SwiftUI

/// Run for query tabs (plan K1, round 15 idea 1): a plain ▶ like its toolbar neighbours, in a
/// capsule of its own so nothing moves when it changes. Running, it becomes ■ with the elapsed
/// time in red (a click cancels); when the query ends it shows ✓ or ! for a moment and settles
/// back. Right-click for the other run modes, which are also in the Query menu.
struct QueryRunToolbarControl: View {
    let tabStore: TabStore

    @State private var result: RunResult?
    @State private var resultTask: Task<Void, Never>?
    @Environment(\.echoMotion) private var motion

    private enum RunResult { case succeeded, failed }

    /// How long ✓ or ! shows after a run.
    private static let resultHold: Duration = .seconds(2.4)

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }
    private var isRunning: Bool { query?.isExecuting ?? false }

    var body: some View {
        Button(action: runOrCancel) { label }
            .buttonStyle(.plain)
            .disabled(!isRunning && !(tab?.canRun(.run) ?? false))
            .help(helpText)
            .accessibilityLabel(helpText)
            .contextMenu {
                ForEach(QueryRunMode.allCases) { mode in
                    Button {
                        tabStore.activeTab?.run(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    .disabled(!(tab?.canRun(mode) ?? false))
                }
            }
            .animation(motion.standard, value: isRunning)
            .animation(motion.standard, value: result)
            .onChange(of: isRunning) { wasRunning, running in
                if running { showResult(nil) } else if wasRunning { showResultOfLastRun() }
            }
            .onChange(of: tab?.id) { _, _ in showResult(nil) }
    }

    @ViewBuilder
    private var label: some View {
        if isRunning, let started = query?.executionStartTime {
            HStack(spacing: SpacingTokens.xxs) {
                Image(systemName: "stop.fill")
                Text(started, style: .timer).monospacedDigit()
            }
            .font(TypographyTokens.detail.weight(.semibold))
            .foregroundStyle(ColorTokens.Status.error)
            .padding(.horizontal, SpacingTokens.xs)
            .frame(height: LayoutTokens.Toolbar.runGlyphSize)
            .background(ColorTokens.Status.error.opacity(LayoutTokens.Toolbar.runningTintOpacity), in: .capsule)
            .contentShape(.capsule)
        } else {
            Image(systemName: symbol)
                .font(TypographyTokens.standard)
                .foregroundStyle(symbolColor)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: LayoutTokens.Toolbar.runGlyphSize, height: LayoutTokens.Toolbar.runGlyphSize)
                .contentShape(Rectangle())
        }
    }

    private var symbol: String {
        switch result {
        case .succeeded: "checkmark"
        case .failed: "exclamationmark"
        case nil: "play.fill"
        }
    }

    private var symbolColor: Color {
        switch result {
        case .succeeded: ColorTokens.Status.success
        case .failed: ColorTokens.Status.error
        case nil: (tab?.canRun(.run) ?? false) ? ColorTokens.Text.primary : ColorTokens.Text.tertiary
        }
    }

    private var helpText: String {
        if isRunning { return "Cancel (⌥⌘.)" }
        return query?.hasActiveSelection == true ? "Run Selection (⌘↩)" : "Run (⌘↩)"
    }

    private func runOrCancel() {
        guard let tab = tabStore.activeTab, let query = tab.query else { return }
        if query.isExecuting {
            query.cancelExecution()
        } else {
            tab.run(.run)
        }
    }

    private func showResultOfLastRun() {
        guard let query, !query.wasCancelled else { return showResult(nil) }
        showResult(query.errorMessage == nil ? .succeeded : .failed)
    }

    private func showResult(_ newResult: RunResult?) {
        resultTask?.cancel()
        result = newResult
        guard newResult != nil else { return }
        resultTask = Task { @MainActor in
            try? await Task.sleep(for: Self.resultHold)
            guard !Task.isCancelled else { return }
            result = nil
        }
    }
}
