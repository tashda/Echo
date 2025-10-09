import SwiftUI

struct AutocompleteManagementWindow: Scene {
    static let sceneID = "autocomplete-management"
    private let coordinator = AppCoordinator.shared

    var body: some Scene {
        WindowGroup(id: Self.sceneID) {
            AutocompleteManagementRootView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
        .defaultSize(width: 1040, height: 680)
    }
}
