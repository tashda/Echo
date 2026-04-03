import SwiftUI

struct AboutWindowScene: Scene {
    static let sceneID = "about-window"
    private let coordinator = AppDirector.shared

    var body: some Scene {
        Window("About Echo", id: Self.sceneID) {
            AboutWindow()
                .environment(coordinator.appearanceStore)
        }
        .defaultSize(width: 840, height: 620)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}
