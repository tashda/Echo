import SwiftUI

/// Generic query editor toolbar controls — shown for all database types when a query tab is active.
/// Separate Liquid Glass group, positioned to the right of database-specific controls.
struct QueryEditorToolbarControls: View {
    @Environment(TabStore.self) private var tabStore

    var body: some View {
        if let tab = tabStore.activeTab, tab.query != nil,
           tab.session is ExecutionPlanProviding {
            EstimatedPlanToolbarButton(tab: tab)
                .glassEffect(.regular.interactive())
        } else {
            EmptyView()
        }
    }
}

// MARK: - Estimated Plan

private struct EstimatedPlanToolbarButton: View {
    let tab: WorkspaceTab

    private var query: QueryEditorState? { tab.query }

    private var isDisabled: Bool {
        guard let query else { return true }
        return query.sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || query.isExecuting
            || query.isLoadingExecutionPlan
    }

    /// True when the plan panel is open and showing the execution plan segment.
    private var isPlanVisible: Bool {
        let panel = tab.panelState
        return panel.isOpen && panel.selectedSegment == .executionPlan
    }

    var body: some View {
        Button {
            if isPlanVisible {
                // Toggle off — close the panel
                tab.panelState.isOpen = false
            } else {
                guard let query else { return }
                let sql = query.sql
                Task { await requestEstimatedPlan(sql: sql) }
            }
        } label: {
            Image(systemName: "chart.bar.doc.horizontal")
        }
        .disabled(!isPlanVisible && isDisabled)
        .help(isPlanVisible ? "Hide Execution Plan" : "Display Estimated Execution Plan")
    }

    private func requestEstimatedPlan(sql: String) async {
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

        // Open the panel and switch to execution plan tab
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
