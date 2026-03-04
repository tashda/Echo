import SwiftUI

struct SettingsWindowScene: Scene {
    static let sceneID = "settings-window"
    private let coordinator = AppCoordinator.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID) {
            SettingsView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environmentObject(coordinator.workspaceSessionStore)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.themeManager)
        }
        .defaultSize(width: 1000, height: 700)
        .windowToolbarStyle(.unified)
        
    }
}
