import SwiftUI

extension ExtendedEventsView {
    var statusBarConfig: BottomPanelStatusBarConfiguration {
        let connText = hostTab?.connection.connectionName ?? "Server"

        var config = BottomPanelStatusBarConfiguration(
            serverName: connText,
            databaseName: nil,
            availableSegments: panelState.availableSegments,
            selectedSegment: panelState.selectedSegment,
            onSelectSegment: { segment in
                if panelState.isOpen && panelState.selectedSegment == segment {
                    panelState.isOpen = false
                } else {
                    panelState.selectedSegment = segment
                    if !panelState.isOpen { panelState.isOpen = true }
                }
            },
            onTogglePanel: { panelState.isOpen.toggle() },
            isPanelOpen: panelState.isOpen
        )

        if !viewModel.eventData.isEmpty {
            config.metrics = .init(
                rowCountText: "\(viewModel.eventData.count)",
                rowCountLabel: viewModel.eventData.count == 1 ? "event" : "events",
                durationText: nil
            )
        }

        if isWatchingLiveData && viewModel.eventDataLoadingState == .loading {
            config.statusBubble = .init(label: "Capturing", tint: .orange, isPulsing: true)
        }

        return config
    }
}
