import SwiftUI

struct AutocompleteInspectorWindow: Scene {
    static let sceneID = "autocomplete-management"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        Window("Autocomplete Management", id: Self.sceneID) {
            AutocompleteInspectorRootView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environment(coordinator.environmentState)
                .environment(coordinator.appState)
                .environment(coordinator.clipboardHistory)
                .environment(AppearanceStore.shared)
        }
        .defaultSize(width: 1040, height: 680)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
