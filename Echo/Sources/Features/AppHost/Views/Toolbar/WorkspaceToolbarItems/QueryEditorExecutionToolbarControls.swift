import SwiftUI

/// Standalone Run button — shown only when a query editor tab is active.
/// Separate Liquid Glass group, positioned as the leftmost query action.
struct QueryRunToolbarItem: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, tab.query != nil {
            QueryRunToolbarButton(tabStore: tabStore)
                .glassEffect(.regular.interactive())
                .id(tab.id)
        }
    }
}

/// Format + Estimated Plan grouped — "enhance my SQL" actions.
/// Separate Liquid Glass group, positioned after the Run button.
struct QueryEditorEnhanceToolbarControls: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, tab.query != nil {
            HStack(spacing: SpacingTokens.none) {
                QueryFormatToolbarButton(tabStore: tabStore)
                if tab.session is ExecutionPlanProviding {
                    EstimatedPlanButton(tabStore: tabStore)
                }
            }
            .glassEffect(.regular.interactive())
            .id(tab.id)
        }
    }
}

// MARK: - Run Button

/// Reads the active tab from TabStore on every action invocation,
/// guaranteeing it always operates on the currently visible tab.
private struct QueryRunToolbarButton: View {
    let tabStore: TabStore

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }

    private var isDisabled: Bool {
        guard let query else { return true }
        return query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isExecuting: Bool {
        query?.isExecuting ?? false
    }

    private var hasSelection: Bool {
        query?.hasActiveSelection ?? false
    }

    var body: some View {
        ToolbarRunButton(
            isRunning: isExecuting,
            isDisabled: isDisabled,
            hasSelection: hasSelection,
            idleLabel: "Run (⌘↩)",
            selectionLabel: "Run Selection (⌘↩)",
            runningLabel: "Cancel (⌘.)"
        ) {
            guard let tab, let query else { return }
            if query.isExecuting {
                query.cancelExecution()
            } else {
                let sql = query.hasActiveSelection
                    ? query.selectedText
                    : query.sql
                guard let action = tab.executeQueryAction else { return }
                Task { await action(sql) }
            }
        }
        .keyboardShortcut(.return, modifiers: [.command])
    }
}

// MARK: - Format Button

/// Reads the active tab's query at action time to ensure it always
/// formats the correct tab's SQL, even after rapid tab switching.
private struct QueryFormatToolbarButton: View {
    let tabStore: TabStore

    private var tab: WorkspaceTab? { tabStore.activeTab }
    private var query: QueryEditorState? { tab?.query }

    @State private var isFormatting = false

    private var isDisabled: Bool {
        guard let query else { return true }
        return isFormatting || query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var dialect: SQLFormatter.Dialect {
        switch tab?.connection.databaseType {
        case .microsoftSQL: .microsoftSQL
        case .mysql: .mysql
        case .sqlite: .sqlite
        default: .postgres
        }
    }

    var body: some View {
        Button(action: formatQuery) {
            if isFormatting {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Label("Format (⇧⌘F)", systemImage: "sparkles")
            }
        }
        .keyboardShortcut("f", modifiers: [.command, .shift])
        .disabled(isDisabled)
        .help("Format SQL (⇧⌘F)")
        .labelStyle(.iconOnly)
        .accessibilityLabel("Format SQL")
    }

    private func formatQuery() {
        // Read the active tab's query at invocation time — not a captured reference
        guard let query = tabStore.activeTab?.query else { return }
        guard !query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !isFormatting else { return }
        isFormatting = true
        let currentSQL = query.sql
        let currentDialect = dialect
        Task {
            do {
                let formatted = try await SQLFormatter.shared.format(sql: currentSQL, dialect: currentDialect)
                // Re-read active tab to confirm it hasn't changed during async work
                if let currentQuery = tabStore.activeTab?.query, currentQuery === query {
                    currentQuery.sql = formatted
                }
            } catch {
                // Formatting failure is non-critical — leave SQL unchanged
            }
            isFormatting = false
        }
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
                Task { await requestEstimatedPlan(tab: tab, sql: sql) }
            }
        } label: {
            Label("Execution Plan", systemImage: "flowchart")
        }
        .disabled(!isPlanVisible && isDisabled)
        .help(isPlanVisible ? "Hide Execution Plan" : "Display Estimated Execution Plan")
        .labelStyle(.iconOnly)
        .accessibilityLabel(isPlanVisible ? "Hide Execution Plan" : "Estimated Execution Plan")
    }

    private func requestEstimatedPlan(tab: WorkspaceTab, sql: String) async {
        guard let query = tab.query,
              let planProvider = tab.session as? ExecutionPlanProviding else { return }

        let trimmedSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSQL.isEmpty else { return }

        var effectiveSQL = trimmedSQL
        if tab.connection.databaseType == .microsoftSQL,
           let selectedDB = tab.activeDatabaseName, !selectedDB.isEmpty {
            effectiveSQL = "USE [\(selectedDB)];\n\(effectiveSQL)"
        }

        query.isLoadingExecutionPlan = true
        query.executionPlan = nil

        let panelState = tab.panelState
        panelState.isOpen = true
        panelState.selectedSegment = .executionPlan

        do {
            let plan = try await planProvider.getEstimatedExecutionPlan(effectiveSQL)
            query.executionPlan = plan
            query.isLoadingExecutionPlan = false
            query.appendMessage(
                message: "Estimated execution plan generated",
                severity: .info,
                category: "Execution Plan"
            )
        } catch {
            query.isLoadingExecutionPlan = false
            query.appendMessage(
                message: "Failed to generate execution plan: \(error.localizedDescription)",
                severity: .error,
                category: "Execution Plan"
            )
        }
    }
}
