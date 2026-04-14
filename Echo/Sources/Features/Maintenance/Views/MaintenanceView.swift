import SwiftUI

struct MaintenanceView: View {
    @Bindable var tab: WorkspaceTab

    var body: some View {
        Group {
            if let vm = tab.mssqlMaintenance {
                MSSQLMaintenanceView(viewModel: vm, panelState: tab.panelState)
            } else if let vm = tab.maintenance {
                switch vm.databaseType {
                case .postgresql:
                    PostgresMaintenanceView(viewModel: vm, panelState: tab.panelState)
                case .mysql, .sqlite:
                    GenericMaintenanceView(viewModel: vm, panelState: tab.panelState)
                case .microsoftSQL:
                    ContentUnavailableView {
                        Label("Maintenance", systemImage: "wrench.and.screwdriver")
                    } description: {
                        Text("Use the SQL Server maintenance tab.")
                    }
                }
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
