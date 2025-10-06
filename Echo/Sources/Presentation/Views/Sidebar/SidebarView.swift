import SwiftUI

struct SidebarView: View {
    @Binding var selectedConnectionID: UUID?
    @Binding var selectedIdentityID: UUID?
    @EnvironmentObject var appModel: AppModel
    @EnvironmentObject var appState: AppState

    var onAddConnection: () -> Void
    private let topPadding: CGFloat = 28

    var body: some View {
        SidebarMenu(
            selectedConnectionID: $selectedConnectionID,
            selectedIdentityID: $selectedIdentityID,
            onAddConnection: onAddConnection
        )
        .environmentObject(appModel)
        .environmentObject(appState)
        .padding(.top, topPadding)
    }
}
