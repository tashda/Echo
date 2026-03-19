import SwiftUI

struct MaintenanceView: View {
    @Bindable var tab: WorkspaceTab

    var body: some View {
        Group {
            if let vm = tab.maintenance {
                PostgresMaintenanceView(viewModel: vm)
            } else if let vm = tab.mssqlMaintenance {
                MSSQLMaintenanceView(viewModel: vm, panelState: tab.panelState)
            } else {
                EmptyStatePlaceholder(
                    icon: "wrench.and.screwdriver",
                    title: "Maintenance",
                    subtitle: "Maintenance is not available for this database type"
                )
            }
        }
        .task {
            if let vm = tab.mssqlMaintenance {
                vm.setPanelState(tab.panelState)
            }
        }
    }
}
