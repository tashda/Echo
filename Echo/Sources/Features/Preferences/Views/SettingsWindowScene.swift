import SwiftUI

struct SettingsWindowScene: Scene {
    static let sceneID = "settings-window"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        Window("Settings", id: Self.sceneID) {
            SettingsView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environmentObject(coordinator.environmentState)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.appearanceStore)
                .environmentObject(coordinator.notificationEngine)
        }
        .defaultSize(width: 1000, height: 700)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
