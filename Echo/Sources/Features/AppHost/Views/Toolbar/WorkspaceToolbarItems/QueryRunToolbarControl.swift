import SwiftUI

/// Run for query tabs (plan K1, rounds 15, 20 and 24): one button in a glass capsule of its own
/// that never swaps for another. At rest a plain ▶ like its neighbours, accent with a selection.
/// Running, ▶ is replaced by ■ in place while the capsule fades to red; then its edge moves out and
/// the time (“5 s”, then “1:05”) fades in. A click or ⌘↩ stops it; while the server is still
/// stopping it says so. When the query ends the red drains as a ✓ draws itself (or ! shows).
/// The tooltip says where it runs, or why it can't. Right-click for the other run modes.
///
/// It draws the red itself, so the item hides the toolbar's shared glass and draws its own
/// (`WorkspaceToolbarItems`), sized like its neighbours (`LayoutTokens.Toolbar`).
struct QueryRunToolbarControl: View {
    let tabStore: TabStore

    @State var stage = Stage.rest
    @State var result: RunResult?
    @State private var task: Task<Void, Never>?
    @Environment(\.echoMotion) var motion

    /// K2, staged: the icon and colour change first, the width just after.
    enum Stage { case rest, red, grown }
    enum RunResult { case succeeded, failed }

    /// How long ✓ or ! shows after a run (T1).
    private static let resultHold: Duration = .seconds(2.4)

    var tab: WorkspaceTab? { tabStore.activeTab }
    var query: QueryEditorState? { tab?.query }
    var isRunning: Bool { query?.isExecuting ?? false }
    var runsSelection: Bool { query?.hasActiveSelection ?? false }
    /// The cancel was sent and the server hasn't stopped yet (J1).
    var isStopping: Bool { isRunning && query?.cancelPhase != nil }
    var canRun: Bool { tab?.canRun(.run) ?? false }

    var body: some View {
        Button(action: runOrStop) {
            HStack(spacing: SpacingTokens.none) {
                glyph
                if stage == .grown, let started = query?.executionStartTime {
                    runningWords(started: started)
                        .padding(.trailing, SpacingTokens.xs)
                        .transition(.asymmetric(
                            insertion: .opacity.animation(motion.settle.delay(motion.settleDuration * 0.6)),
                            removal: .opacity))
                }
            }
            .background { redFill }
            .clipShape(.capsule)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(isRunning ? isStopping : !canRun)
        .padding(.horizontal, LayoutTokens.Toolbar.capsuleHorizontalPadding)
        .padding(.vertical, LayoutTokens.Toolbar.capsuleVerticalPadding)
        .glassEffect(.regular.interactive(), in: .capsule)
        .help(helpText)
        .accessibilityLabel(helpText)
        .contextMenu { modeItems }
        .animation(motion.settle, value: stage)
        .animation(motion.settle, value: result)
        .animation(motion.settle, value: isStopping)
        .animation(motion.hover, value: runsSelection)
        .onChange(of: isRunning) { wasRunning, running in
            if running { begin() } else if wasRunning { end() }
        }
    }

    @ViewBuilder
    private var modeItems: some View {
        ForEach(QueryRunMode.allCases) { mode in
            Button {
                tabStore.activeTab?.run(mode)
            } label: {
                Label(mode.title, systemImage: mode.systemImage)
            }
            .disabled(!(tab?.canRun(mode) ?? false))
        }
        if let tab, tab.supportsRunAsOneTransaction {
            Divider()
            Toggle("Run as One Transaction", isOn: tab.runAsOneTransactionBinding)
        }
    }

    private func runOrStop() {
        guard let tab = tabStore.activeTab, let query = tab.query else { return }
        if query.isExecuting {
            guard query.cancelPhase == nil else { return }
            query.cancelExecution()
        } else {
            tab.run(.run)
        }
    }

    // MARK: Stages

    /// ■ and the red at once, then the width and the time.
    private func begin() {
        task?.cancel()
        result = nil
        stage = .red
        task = Task { @MainActor in
            try? await Task.sleep(for: .seconds(motion.settleDuration * 0.55))
            guard !Task.isCancelled, isRunning else { return }
            stage = .grown
        }
    }

    /// B0: the red drains and the capsule shrinks as the ✓ draws; a cancel goes straight back (Z0).
    private func end() {
        task?.cancel()
        stage = .rest
        guard let query, !query.wasCancelled else { result = nil; return }
        result = query.errorMessage == nil ? .succeeded : .failed
        task = Task { @MainActor in
            try? await Task.sleep(for: Self.resultHold)
            guard !Task.isCancelled else { return }
            result = nil
        }
    }
}
