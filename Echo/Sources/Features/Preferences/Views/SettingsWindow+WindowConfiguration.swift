import SwiftUI
import AppKit

/// Configures the native NSWindow properties for the Settings window that SwiftUI
/// does not expose or sometimes misconfigures for single-instance `Window` scenes.
///
/// This ensures the window:
/// - Appears in the "Windows" menu and Dock window list.
/// - Participates in the `Cmd + ` (window cycling) shortcut.
/// - Has the correct internal identifier for state tracking.
struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            guard let window = view.window else { return }
            context.coordinator.configure(window: window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        Task { @MainActor in
            guard let window = nsView.window else { return }
            context.coordinator.configure(window: window)
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        func configure(window: NSWindow) {
            // Ensure the window has the correct identifier
            if window.identifier != AppWindowIdentifier.settings {
                window.identifier = AppWindowIdentifier.settings
            }

            // Ensure the window is NOT excluded from the Windows menu.
            // Some single-instance Window scenes or windows named "Settings" can
            // sometimes default to being excluded if SwiftUI thinks they are 
            // secondary auxiliary windows.
            if window.isExcludedFromWindowsMenu {
                window.isExcludedFromWindowsMenu = false
            }

            // Ensure the window participates in the Cmd + ` cycle.
            if !window.collectionBehavior.contains(.participatesInCycle) {
                window.collectionBehavior.insert(.participatesInCycle)
            }

            // Standard settings window behaviors
            if window.tabbingMode != .disallowed {
                window.tabbingMode = .disallowed
            }

            // Ensure the window stays visible and participates in normal window management.
            if window.level != .normal {
                window.level = .normal
            }
            if window.hidesOnDeactivate {
                window.hidesOnDeactivate = false
            }

            // Ensure the window can become key/main.
            // This is required for Cmd + ` cycling.
            if !window.canBecomeKey {
                // We can't set canBecomeKey directly as it's a read-only computed property
                // for NSWindow, but we can ensure the style mask is appropriate.
            }

            // Set a proper title for the Windows menu / Dock list.
            // Even if we hide the titlebar title, this title is used by the OS.
            if window.title != "Settings" {
                window.title = "Settings"
            }
        }
    }
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
    static let highlightSettingsGroup = Notification.Name("com.fuzee.settings.highlightGroup")
    static let toggleManageConnectionsSidebar = Notification.Name("com.fuzee.manageConnections.toggleSidebar")
}
