import SwiftUI

/// Builds a `BottomPanelStatusBar` configured for query tabs.
struct QueryPanelStatusBar: View {
    @Bindable var query: QueryEditorState
    @Bindable var panelState: BottomPanelState
    let connectionText: String

    var body: some View {
        BottomPanelStatusBar(configuration: configuration)
    }

    private var hasActivity: Bool {
        query.hasExecutedAtLeastOnce || query.isExecuting || query.errorMessage != nil
    }

    private var visibleSegments: [PanelSegment] {
        panelState.availableSegments.filter { segment in
            switch segment {
            case .executionPlan:
                return query.executionPlan != nil
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
            connectionText: connectionText,
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

        if hasActivity {
            config.metrics = buildMetrics()
            config.statusBubble = buildStatusBubble()
        }

        return config
    }

    private func buildMetrics() -> BottomPanelStatusBarConfiguration.Metrics {
        let rowCount = EchoFormatters.compactNumber(query.rowProgress.displayCount)
        let rowLabel = query.rowProgress.displayCount == 1 ? "row" : "rows"
        let elapsed = query.isExecuting ? query.currentExecutionTime : (query.lastExecutionTime ?? 0)
        let hasDuration = query.isExecuting || query.lastExecutionTime != nil
        let durationText = hasDuration ? EchoFormatters.duration(seconds: Int(elapsed.rounded())) : nil

        return .init(rowCountText: rowCount, rowCountLabel: rowLabel, durationText: durationText)
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
            return .init(label: "Completed", tint: .green, isPulsing: false)
        }
        return .init(label: "Ready", tint: .secondary, isPulsing: false)
    }
}
