import SwiftUI

struct SettingsWindowScene: Scene {
    static let sceneID = "settings-window"
    private let coordinator = AppCoordinator.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID) {
            SettingsView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.themeManager)
        }
        .defaultSize(width: 1000, height: 700)
        .windowToolbarStyle(.unified)
        
    }
}
