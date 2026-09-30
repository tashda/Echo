import EchoSense
import SwiftUI

/// Builds a `BottomPanelStatusBar` configured for query tabs.
struct QueryPanelStatusBar: View {
    @Bindable var query: QueryEditorState
    @Bindable var panelState: BottomPanelState
    let serverName: String
    let databaseName: String?
    let availableDatabases: [String]
    let onSwitchDatabase: ((String) -> Void)?
    /// Runs COMMIT or ROLLBACK from the transaction pill's menu (round 21, TA2).
    var onRunCommand: ((String) -> Void)?
    /// The server a connection with several moved to (round 23, FS1).
    var serverMove: ConnectionServerMove?

    @State private var showStatisticsPopover = false
    @State private var showDatabasePicker = false

    var body: some View {
        BottomPanelStatusBar(configuration: configuration)
    }

    private var hasActivity: Bool {
        query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil || query.isEstablishingConnection
            || query.connectionLoss != nil || query.transactionState != .none
    }

    private var visibleSegments: [PanelSegment] {
        panelState.availableSegments.filter { segment in
            switch segment {
            case .executionPlan:
                return query.executionPlan != nil
            case .spatial:
                return query.displayedColumns.contains { SpatialExtractor.isSpatialColumn($0.dataType) }
            default:
                return true
            }
        }
    }

    private var configuration: BottomPanelStatusBarConfiguration {
        let disabledSegments: Set<PanelSegment> = hasActivity ? [] : Set(
            visibleSegments.filter { $0 != .results }
        )

        var config = BottomPanelStatusBarConfiguration(
            serverName: serverName,
            databaseName: databaseName,
            availableSegments: visibleSegments,
            disabledSegments: disabledSegments,
            selectedSegment: panelState.selectedSegment,
            onSelectSegment: { segment in
                if panelState.isOpen && panelState.selectedSegment == segment {
                    panelState.isOpen = false
                } else {
                    panelState.selectedSegment = segment
                    if !panelState.isOpen { panelState.isOpen = true }
                }
            },
            onTogglePanel: {
                panelState.isOpen.toggle()
            },
            isPanelOpen: panelState.isOpen
        )

        config.statusBubble = buildStatusBubble()
        if hasActivity {
            config.metrics = buildMetrics()
        }

        config.modeIndicators = buildModeIndicators()

        if hasPerformanceReport {
            config.statisticsPopover = AnyView(
                QueryPerformanceReportView(query: query)
            )
            config.showStatisticsPopover = $showStatisticsPopover
        }

        if !availableDatabases.isEmpty, onSwitchDatabase != nil {
            config.availableDatabases = availableDatabases
            config.onSwitchDatabase = onSwitchDatabase
            config.showDatabasePicker = $showDatabasePicker
        }

        return config
    }

    private var hasPerformanceReport: Bool {
        query.isExecuting || query.livePerformanceReport != nil || query.lastPerformanceReport != nil
    }

    private func buildMetrics() -> BottomPanelStatusBarConfiguration.Metrics {
        // Rows loaded of the total while streaming (plan R5), then the total.
        let rowCount = GridSelectionSummary.rowCountText(
            for: query.rowProgress,
            isExecuting: query.isExecuting,
            compact: EchoFormatters.compactNumber
        )
        var rowLabel = query.rowProgress.displayCount == 1 ? "row" : "rows"
        // Round 21, cancel CP1: rows kept after a cancel are marked as partial.
        if query.wasCancelled, !query.isExecuting, query.rowProgress.displayCount > 0 { rowLabel += ", partial" }
        let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        var durationText = hasDuration ? EchoFormatters.duration(seconds: Int(elapsed.rounded())) : nil
        // Round 21, timeouts (FT1): the limit next to the timer while a statement runs under one.
        if query.isExecuting, let limit = query.timeLimit, let text = durationText {
            durationText = "\(text) / \(EchoFormatters.duration(seconds: Int(limit.rounded())))"
        }

        var metrics = BottomPanelStatusBarConfiguration.Metrics(rowCountText: rowCount, rowCountLabel: rowLabel, durationText: durationText)
        metrics.selectionText = query.gridSelectionSummary.flatMap { $0.cellCount > 1 ? $0.text : nil }
        return metrics
    }

    private func buildModeIndicators() -> [BottomPanelStatusBarConfiguration.ModeIndicator] {
        var indicators: [BottomPanelStatusBarConfiguration.ModeIndicator] = []
        if query.sqlcmdModeEnabled {
            indicators.append(.init(id: "sqlcmd", label: "SQLCMD", icon: "terminal"))
        }
        if query.statisticsEnabled {
            indicators.append(.init(id: "statistics", label: "Statistics", icon: "chart.bar"))
        }
        if let serverMove {
            indicators.append(.init(id: "server", label: serverMove.label, icon: "arrow.triangle.swap", help: serverMove.help))
        }
        return indicators
    }

    /// Commit and Roll Back one click from the pill (TA2); a failed transaction can only roll back.
    private func transactionMenu(failed: Bool) -> [BottomPanelStatusBarConfiguration.StatusBubble.MenuItem] {
        var items: [BottomPanelStatusBarConfiguration.StatusBubble.MenuItem] = []
        if let onRunCommand {
            if !failed { items.append(.init(title: "Commit", systemImage: "checkmark.circle") { onRunCommand("COMMIT") }) }
            items.append(.init(title: "Roll Back", systemImage: "arrow.uturn.backward", isDestructive: !failed) { onRunCommand("ROLLBACK") })
        }
        items.append(.init(title: "Show in Messages", systemImage: "text.bubble") {
            panelState.isOpen = true
            panelState.selectedSegment = .messages
        })
        return items
    }

    private func buildStatusBubble() -> BottomPanelStatusBarConfiguration.StatusBubble {
        if query.cancelPhase != nil {
            return .init(label: "Cancelling", tint: .orange, isPulsing: true)
        }
        // Round 21, timeouts (LF3): a statement waiting for a lock says so; hover shows who holds it.
        if query.isExecuting, let wait = query.lockWait {
            return .init(label: "Waiting for lock", tint: ColorTokens.Status.warning, isPulsing: false,
                         icon: "lock", help: wait.summary())
        }
        if query.isExecuting {
            return .init(label: "Executing", tint: .orange, isPulsing: true)
        }
        if query.connectionLoss != nil {
            return .init(label: "Disconnected", tint: .red, isPulsing: false)
        }
        // Round 21, transaction state: the status pill shows an open or failed transaction.
        switch query.transactionState {
        case .open(let since):
            return .init(label: "Transaction", tint: ColorTokens.Status.warning, isPulsing: false,
                         icon: "arrow.triangle.branch", since: since, menu: transactionMenu(failed: false))
        case .failed:
            return .init(label: "Failed — roll back", tint: ColorTokens.Status.error, isPulsing: false,
                         icon: "exclamationmark.octagon", menu: transactionMenu(failed: true))
        case .none:
            break
        }
        if query.wasCancelled {
            return .init(label: "Cancelled", tint: .yellow, isPulsing: false)
        }
        if let error = query.errorMessage, !error.isEmpty {
            return .init(label: "Error", tint: .red, isPulsing: false)
        }
        if query.hasExecutedAtLeastOnce {
            let isMaterializing = query.rowProgress.materialized < query.rowProgress.totalReported
                && query.rowProgress.totalReported > 0
            return .init(
                label: isMaterializing ? "Loading rows" : "Completed",
                tint: .green,
                isPulsing: isMaterializing
            )
        }
        if query.isLoadingCrossDBSchema, let target = query.crossDBSchemaTarget {
            return .init(label: "Loading \(target)…", tint: .secondary, isPulsing: true)
        }
        if query.isEstablishingConnection {
            return .init(label: "Connecting", tint: .secondary, isPulsing: true)
        }
        return .init(label: "Ready", tint: .secondary, isPulsing: false)
    }
}
