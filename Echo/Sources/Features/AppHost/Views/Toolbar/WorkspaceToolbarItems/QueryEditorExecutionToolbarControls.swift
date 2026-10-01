import SwiftUI
import EchoSense

/// Standalone Run button — shown only when a query editor tab is active.
/// Separate Liquid Glass group, positioned as the leftmost query action.
struct QueryRunToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if tabStore.activeTabToolbarContext.isQuery, let tab = tabStore.activeTab, tab.query != nil {
            // No `.id(tab.id)`: a new identity per tab re-creates the window's toolbar items on
            // every tab switch. The control takes the new tab's state itself.
            QueryRunToolbarControl(tabStore: tabStore)
        }
    }
}

/// Format, Validate, Context Help and Estimated Plan: the query tab's own group, after Run.
struct QueryEditorEnhanceToolbarControls: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if tabStore.activeTabToolbarContext.isQuery, let tab = tabStore.activeTab, tab.query != nil {
            HStack(spacing: SpacingTokens.none) {
                QueryFormatToolbarButton(tabStore: tabStore)
                QueryValidateToolbarButton(tabStore: tabStore)
                QueryContextHelpToolbarButton(tabStore: tabStore)
                if tab.session is ExecutionPlanProviding {
                    EstimatedPlanButton(tabStore: tabStore)
                }
            }
        }
    }
}

private struct QueryContextHelpToolbarButton: View {
    let tabStore: TabStore
    @Environment(EnvironmentState.self) private var environmentState
    @Environment(AppState.self) private var appState

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }

    private var selectedText: String {
        query?.selectedText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var isDisabled: Bool {
        guard let tab else { return true }
        guard !selectedText.isEmpty else { return true }
        return SQLHelpInspectorContentProvider().content(
            for: selectedText,
            databaseType: EchoSenseDatabaseType(tab.connection.databaseType)
        ) == nil
    }

    private var isShowingHelp: Bool {
        guard case .sqlHelp = environmentState.dataInspectorContent else { return false }
        return appState.showInfoSidebar
    }

    var body: some View {
        Button {
            toggleHelp()
        } label: {
            Label("Context Help", systemImage: "text.book.closed")
        }
        .disabled(isDisabled)
        .help(isShowingHelp ? "Hide Context Help" : "Show Context Help for Selection")
        .labelStyle(.iconOnly)
        .accessibilityLabel(isShowingHelp ? "Hide Context Help" : "Show Context Help")
    }

    private func toggleHelp() {
        guard let tab,
              let content = SQLHelpInspectorContentProvider().content(
                for: selectedText,
                databaseType: EchoSenseDatabaseType(tab.connection.databaseType)
              ) else { return }

        environmentState.toggleDataInspector(
            content: .sqlHelp(content),
            title: "sql-help-\(content.title)",
            appState: appState
        )
    }
}

// MARK: - Format Button

/// Reads the active tab's query at action time to ensure it always
/// formats the correct tab's SQL, even after rapid tab switching.
private struct QueryFormatToolbarButton: View {
    let tabStore: TabStore

    @State private var isFormatting = false

    private var isDisabled: Bool {
        isFormatting || !(tabStore.activeTab?.canRunQuery ?? false)
    }

    var body: some View {
        Button {
            guard let tab = tabStore.activeTab, !isFormatting else { return }
            isFormatting = true
            Task {
                await tab.formatSQL()
                isFormatting = false
            }
        } label: {
            if isFormatting {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Label("Format", systemImage: "sparkles")
            }
        }
        .disabled(isDisabled)
        .help("Format SQL (⇧⌘F)")
        .labelStyle(.iconOnly)
        .accessibilityLabel("Format SQL")
    }
}

// MARK: - Estimated Plan Button

private struct EstimatedPlanButton: View {
    let tabStore: TabStore

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }

    private var isDisabled: Bool {
        guard let query else { return true }
        return query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || query.isExecuting
            || query.isLoadingExecutionPlan
    }

    private var isPlanVisible: Bool {
        guard let tab else { return false }
        let panel = tab.panelState
        return panel.isOpen && panel.selectedSegment == .executionPlan
    }

    var body: some View {
        Button {
            guard let tab else { return }
            if isPlanVisible {
                tab.panelState.isOpen = false
            } else {
                guard let query else { return }
                let sql = query.sql
                Task { await tab.requestExecutionPlan(sql: sql, actual: false) }
            }
        } label: {
            Label("Execution Plan", systemImage: "flowchart")
        }
        .disabled(!isPlanVisible && isDisabled)
        .help(isPlanVisible ? "Hide Execution Plan" : "Display Estimated Execution Plan")
        .labelStyle(.iconOnly)
        .accessibilityLabel(isPlanVisible ? "Hide Execution Plan" : "Estimated Execution Plan")
    }
}

// MARK: - Validate Button

private struct QueryValidateToolbarButton: View {
    let tabStore: TabStore

    private var query: QueryEditorState? { tabStore.activeTab?.query }

    private var isDisabled: Bool {
        guard let query else { return true }
        return query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Button {
            tabStore.activeTab?.validateSQL()
        } label: {
            Label("Validate", systemImage: "exclamationmark.triangle")
        }
        .disabled(isDisabled)
        .help("Validate SQL (⇧⌘B)")
        .labelStyle(.iconOnly)
        .accessibilityLabel("Validate SQL")
    }
}
