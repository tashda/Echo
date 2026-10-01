import SwiftUI

/// The Explorer tree and the rail's tool pages, on the canvas beside the rail.
struct SidebarColumn: View {
    let railBridge: ServerRailBridge

    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(AppState.self) private var appState

    var body: some View {
        SidebarView(
            selectedConnectionID: Binding(
                get: { connectionStore.selectedConnectionID },
                set: { connectionStore.selectedConnectionID = $0 }
            ),
            selectedIdentityID: Binding(
                get: { connectionStore.selectedIdentityID },
                set: { connectionStore.selectedIdentityID = $0 }
            ),
            railBridge: railBridge,
            onAddConnection: { appState.showSheet(.connectionEditor) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The tab strip and the active tab, on the canvas beside the tree.
struct WorkspaceMainContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let tabBarStyle = appState.workspaceTabBarStyle
        WorkspaceTabContainerView(
            showsTabStrip: tabBarStyle.showsFloatingStrip,
            tabBarLeadingPadding: SpacingTokens.none,
            tabBarTrailingPadding: SpacingTokens.none
        )
        .environment(\.useNativeTabBar, false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: tabBarStyle.contentVerticalOffset)
    }
}
