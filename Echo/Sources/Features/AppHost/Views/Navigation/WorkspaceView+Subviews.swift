import SwiftUI

struct SidebarColumn: View {
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
            onAddConnection: { appState.showSheet(.connectionEditor) }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        #if os(macOS)
        .background(
            SidebarSplitViewObserver(width: Bindable(appState).workspaceSidebarWidth)
        )
        #endif
    }
}

struct WorkspaceMainContent: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let tabBarStyle = appState.workspaceTabBarStyle
        WorkspaceTabContainerView(
            showsTabStrip: tabBarStyle.showsFloatingStrip,
            tabBarLeadingPadding: 8,
            tabBarTrailingPadding: 8
        )
        .environment(\.useNativeTabBar, false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .offset(y: tabBarStyle.contentVerticalOffset)
    }
}

enum WorkspaceLayoutMetrics {
    static let sidebarMinWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 320

    static let inspectorMinWidth: CGFloat = 300
    static let inspectorIdealWidth: CGFloat = 300
    static let inspectorMaxWidth: CGFloat = 1600
    static let jsonInspectorWidth: CGFloat = 600
}
