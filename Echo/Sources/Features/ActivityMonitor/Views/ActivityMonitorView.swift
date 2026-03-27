import SwiftUI

struct ActivityMonitorView: View {
    @Bindable var viewModel: ActivityMonitorViewModel

    var body: some View {
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
        }
    }
}
