import AppKit
import SwiftUI
import UserNotifications

@main
struct EchoLabApp: App {
    init() {
        // `EchoLab --notify "text"` posts a notification with Echo Labs' own icon and exits. The
        // build script uses it so "Building…" and "Ready" carry the Labs icon.
        if let index = CommandLine.arguments.firstIndex(of: "--notify"), CommandLine.arguments.indices.contains(index + 1) {
            Self.postNotificationAndExit(CommandLine.arguments[index + 1])
        }
        // Ask once to post notifications; the build script's "Building…" and "Ready" use them.
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
        }
        // A SwiftPM executable has no app bundle, so ask for a Dock icon and a key window.
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate()
    }

    private static func postNotificationAndExit(_ text: String) -> Never {
        let center = UNUserNotificationCenter.current()
        let finished = DispatchSemaphore(value: 0)
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { finished.signal(); return }
            let content = UNMutableNotificationContent()
            content.title = "Echo Labs"
            content.body = text
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)) { _ in finished.signal() }
        }
        _ = finished.wait(timeout: .now() + 6)
        exit(0)
    }

    var body: some Scene {
        Window("Echo Labs", id: "lab") {
            LabRootView()
        }
        .defaultSize(width: 1280, height: 860)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Zoom In") { LabZoom.shared.zoomIn() }.keyboardShortcut("=", modifiers: .command)
                Button("Zoom Out") { LabZoom.shared.zoomOut() }.keyboardShortcut("-", modifiers: .command)
                Button("Actual Size") { LabZoom.shared.reset() }.keyboardShortcut("0", modifiers: .command)
            }
            CommandMenu("Build") {
                Button("Rebuild and Relaunch") { LabBuilder.shared.rebuild() }
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                Button("Relaunch") { LabBuilder.shared.relaunch() }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}
