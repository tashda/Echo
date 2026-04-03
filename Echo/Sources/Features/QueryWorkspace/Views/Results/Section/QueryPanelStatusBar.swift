import SwiftUI

/// Builds a `BottomPanelStatusBar` configured for query tabs.
struct QueryPanelStatusBar: View {
    @Bindable var query: QueryEditorState
    @Bindable var panelState: BottomPanelState
    let serverName: String
    let databaseName: String?
    let availableDatabases: [String]
    let onSwitchDatabase: ((String) -> Void)?

    @State private var showStatisticsPopover = false
    @State private var showDatabasePicker = false

    var body: some View {
        BottomPanelStatusBar(configuration: configuration)
    }

    private var hasActivity: Bool {
        query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil || query.isEstablishingConnection
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
        let rowCount = EchoFormatters.compactNumber(query.rowProgress.displayCount)
        let rowLabel = query.rowProgress.displayCount == 1 ? "row" : "rows"
        let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        let durationText = hasDuration ? EchoFormatters.duration(seconds: Int(elapsed.rounded())) : nil

        return .init(rowCountText: rowCount, rowCountLabel: rowLabel, durationText: durationText)
    }

    private func buildModeIndicators() -> [BottomPanelStatusBarConfiguration.ModeIndicator] {
        var indicators: [BottomPanelStatusBarConfiguration.ModeIndicator] = []
        if query.sqlcmdModeEnabled {
            indicators.append(.init(id: "sqlcmd", label: "SQLCMD", icon: "terminal"))
        }
        if query.statisticsEnabled {
            indicators.append(.init(id: "statistics", label: "Statistics", icon: "chart.bar"))
        }
        return indicators
    }

    private func buildStatusBubble() -> BottomPanelStatusBarConfiguration.StatusBubble {
        if query.isExecuting {
            return .init(label: "Executing", tint: .orange, isPulsing: true)
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
