import SwiftUI

struct DatabaseSecurityView: View {
    @Bindable var tab: WorkspaceTab

    var body: some View {
        Group {
            if let vm = tab.databaseSecurity {
                MSSQLDatabaseSecurityView(viewModel: vm, panelState: tab.panelState)
            } else {
                ContentUnavailableView(
                    "Security Unavailable",
                    systemImage: "lock.shield",
                    description: Text("Security management is not available for this connection.")
                )
            }
        }
        .task {
            if let vm = tab.databaseSecurity {
                vm.setPanelState(tab.panelState)
            }
        }
    }
}
