import SwiftUI

struct SidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    
    @EnvironmentObject var environmentState: EnvironmentState
    @EnvironmentObject var appState: AppState

    var onAddConnection: () -> Void

    var body: some View {
        SidebarMenu(
            selectedConnectionID: $selectedConnectionID,
            selectedIdentityID: $selectedIdentityID,
            onAddConnection: onAddConnection
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
