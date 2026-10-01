import SwiftUI

struct ActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel
    @Environment(\.keptAliveTabsActivity) private var tabsActivity
    @Environment(\.keptAliveTabID) private var tabID

    var body: some View {
        content
            .onChange(of: KeptAliveTabsActivity.isActive(tabID, in: tabsActivity), initial: true) { _, shown in
                viewModel.setShown(shown)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.databaseType {
        case .microsoftSQL:
            MSSQLActivityMonitorView(viewModel: viewModel)
        case .postgresql:
            PostgresActivityMonitorView(viewModel: viewModel)
        case .mysql:
            MySQLActivityMonitorView(viewModel: viewModel)
        case .sqlite:
            ContentUnavailableView {
                Label("Activity Monitor", systemImage: "gauge.with.dots.needle.33percent")
            } description: {
                Text("Activity monitoring is not available for SQLite.")
            }
            .workspaceCard()
        }
    }
}
