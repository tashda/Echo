import SwiftUI

struct SidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var appState: AppState

    var onAddConnection: () -> Void

    var body: some View {
        SidebarMenu(
            selectedConnectionID: $selectedConnectionID,
            selectedIdentityID: $selectedIdentityID,
            onAddConnection: onAddConnection
        )
        .environmentObject(appModel)
        .environmentObject(appState)
    }
}
