import SwiftUI

/// Shared container for all activity monitor views. Provides the toolbar, loading/permission states,
/// sparkline + section content layout, and SQL inspector sheet — so each database-specific activity
/// monitor only needs to supply its sparklines, section content, and onChange handlers. Its pages are
/// chosen in the tab (ST2).
struct ActivityMonitorTabFrame<Sparklines: View, SectionContent: View>: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    let hasPermission: Bool
    let hasSnapshot: Bool
    @Binding var selectedSQLContext: SQLPopoutContext?
    let onOpenInQueryWindow: (_ sql: String, _ database: String?) -> Void
    @ViewBuilder let sparklines: () -> Sparklines
    @ViewBuilder let sectionContent: () -> SectionContent

    @Environment(EnvironmentState.self) private var environmentState
    @Environment(ProjectStore.self) private var projectStore
    @Environment(\.keptAliveTabsActivity) private var tabsActivity
    @Environment(\.keptAliveTabID) private var tabID
    /// Live dates tick only while this tab is on screen (owner's choice, 2026-10-01).
    private var isOnScreen: Bool { KeptAliveTabsActivity.isActive(tabID, in: tabsActivity) }

    var body: some View {
        // TT2 + TT3: the tool header on the canvas, the figures as tiles, then the page on its
        // own card. The pages are chosen in the tab itself (ST2).
        VStack(spacing: projectStore.globalSettings.workspaceGutter.points) {
            ToolTabHeader(systemImage: "waveform.path.ecg", tint: ColorTokens.Status.warning,
                          title: "Activity Monitor", subtitle: headerSubtitle) {
                headerControls
            }
            if !hasPermission {
                permissionDeniedView.workspaceCard()
            } else if !hasSnapshot {
                loadingView.workspaceCard()
            } else {
                sparklines()
                sectionContent()
                    .background(ColorTokens.Background.primary)
                    .workspaceCard()
            }
        }
        .tabContentFrame()
        .sheet(item: $selectedSQLContext) { context in
            SQLInspectorSheet(context: context) { sql, database in
                onOpenInQueryWindow(sql, database)
            }
        }
    }

    /// How often it samples, Refresh, and Pause or Resume on the header line (round 37.2, 37.3);
    /// Pause was an eye in the window toolbar before round 45.
    @ViewBuilder
    private var headerControls: some View {
        ToolTabPickerPill(
            title: "Refresh Interval", systemImage: "timer",
            selection: Binding(get: { viewModel.refreshInterval }, set: { interval in
                viewModel.refreshInterval = interval
                if viewModel.isRunning { viewModel.startStreaming() }
            }),
            options: Self.intervals,
            label: { "Every \(Int($0)) s" }
        )
        ToolTabActionGroup {
            ToolTabActionButton(title: "Refresh Now", systemImage: "arrow.clockwise") { viewModel.refresh() }
        }
        ToolTabPrimaryButton(title: viewModel.isRunning ? "Pause" : "Resume",
                             systemImage: viewModel.isRunning ? "pause.fill" : "play.fill") {
            if viewModel.isRunning { viewModel.stopStreaming() } else { viewModel.startStreaming() }
        }
    }

    private static var intervals: [TimeInterval] { [1, 2, 5, 10, 30] }

    /// The server, and how fresh the figures are.
    private var headerSubtitle: Text {
        let server = environmentState.sessionGroup.sessionForConnection(viewModel.connectionID)?.connection.connectionName ?? ""
        let lastUpdate = viewModel.cpuHistory.last?.timestamp ?? viewModel.connectionCountHistory.last?.timestamp
        let prefix = server.isEmpty ? "" : "\(server) · "
        if !viewModel.isRunning { return Text("\(prefix)Paused") }
        guard let lastUpdate else { return Text("\(prefix)Waiting for the first snapshot") }
        return Text("\(prefix)Updated \(SinceDateText.text(since: lastUpdate, isLive: isOnScreen)) ago")
    }

    private var permissionDeniedView: some View {
        ContentUnavailableView {
            Label("Insufficient Permissions", systemImage: "lock.shield")
        } description: {
            Text("Activity Monitor requires VIEW SERVER STATE permission on this server. Contact your database administrator to grant access.")
        }
    }

    private var loadingView: some View {
        TabInitializingPlaceholder(
            icon: "gauge.with.dots.needle.33percent",
            title: "Initializing Activity Monitor",
            subtitle: "Waiting for the first snapshot\u{2026}"
        )
    }
}
