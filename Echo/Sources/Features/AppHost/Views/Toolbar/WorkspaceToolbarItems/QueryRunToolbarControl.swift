import SwiftUI

/// Run for query tabs (plan K1, round 15 idea 1): a standard toolbar button like its neighbours,
/// in a capsule of its own. With a selection it turns accent, as it runs only the selection.
/// Running, the whole capsule turns red (the system's prominent glass) with ■ and the elapsed time;
/// a click cancels. When the query ends it shows ✓ or ! for a moment and settles back.
/// Right-click for the other run modes, which are also in the Query menu.
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
    private var runsSelection: Bool { query?.hasActiveSelection ?? false }

    var body: some View {
        Group {
            if isRunning, let started = query?.executionStartTime {
                Button(action: runOrCancel) {
                    Label {
                        Text(started, style: .timer).monospacedDigit()
                    } icon: {
                        Image(systemName: "stop.fill")
                    }
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.glassProminent)
                .tint(ColorTokens.Status.error)
            } else {
                Button(action: runOrCancel) {
                    Label(runsSelection ? "Run Selection" : "Run", systemImage: symbol)
                        .foregroundStyle(symbolColor)
                        .contentTransition(.symbolEffect(.replace))
                }
                .labelStyle(.iconOnly)
                .disabled(!(tab?.canRun(.run) ?? false))
            }
        }
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
        .animation(motion.hover, value: runsSelection)
        .onChange(of: isRunning) { wasRunning, running in
            if running { showResult(nil) } else if wasRunning { showResultOfLastRun() }
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
        case nil: runsSelection ? ColorTokens.accent : ColorTokens.Text.primary
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
