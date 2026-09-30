import AppKit
import SwiftUI

@main
struct EchoLabApp: App {
    init() {
        // A SwiftPM executable has no app bundle, so ask for a Dock icon and a key window.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    var body: some Scene {
        Window("Echo Lab", id: "lab") {
            LabRootView()
        }
        .defaultSize(width: 1280, height: 860)
    }
}
