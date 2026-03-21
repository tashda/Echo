import SwiftUI

struct MaintenanceView: View {
    @Bindable var tab: WorkspaceTab

    var body: some View {
        Group {
            if let vm = tab.maintenance {
                PostgresMaintenanceView(viewModel: vm, panelState: tab.panelState)
            } else if let vm = tab.mssqlMaintenance {
                MSSQLMaintenanceView(viewModel: vm, panelState: tab.panelState)
            } else {
                ContentUnavailableView {
                    Label("Maintenance", systemImage: "wrench.and.screwdriver")
                } description: {
                    Text("Maintenance is not available for this database type.")
                }
            }
        }
        .task {
            if let vm = tab.mssqlMaintenance {
                vm.setPanelState(tab.panelState)
            } else if let vm = tab.maintenance {
                vm.setPanelState(tab.panelState)
            }
        }
    }
}
