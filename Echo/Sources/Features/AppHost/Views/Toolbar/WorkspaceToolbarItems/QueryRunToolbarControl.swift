import SwiftUI

/// Run for query tabs (plan K1): the toolbar's one tinted item. Accent glass when idle, red with the
/// elapsed time while running (a click cancels), and a chevron with the other run modes.
/// Shortcuts live on the Query menu, so this view binds none.
struct QueryRunToolbarControl: View {
    let tabStore: TabStore

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }
    private var isRunning: Bool { query?.isExecuting ?? false }

    var body: some View {
        HStack(spacing: SpacingTokens.xxxs) {
            Button(action: runOrCancel) { runLabel }
                .buttonStyle(.glassProminent)
                .tint(isRunning ? ColorTokens.Status.error : ColorTokens.accent)
                .disabled(!isRunning && !(tab?.canRun(.run) ?? false))
                .help(helpText)
                .accessibilityLabel(helpText)

            Menu {
                ForEach(QueryRunMode.allCases) { mode in
                    Button {
                        tabStore.activeTab?.run(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    .disabled(!(tab?.canRun(mode) ?? false))
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(TypographyTokens.caption2.weight(.semibold))
            }
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Run Options")
            .accessibilityLabel("Run Options")
        }
        .animation(.default, value: isRunning)
    }

    @ViewBuilder
    private var runLabel: some View {
        if isRunning, let started = query?.executionStartTime {
            Label {
                Text(started, style: .timer).monospacedDigit()
            } icon: {
                Image(systemName: "stop.fill")
            }
            .labelStyle(.titleAndIcon)
        } else {
            Label(query?.hasActiveSelection == true ? "Run Selection" : "Run", systemImage: "play.fill")
                .labelStyle(.iconOnly)
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
}
