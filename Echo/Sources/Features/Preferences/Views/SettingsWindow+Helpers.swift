import SwiftUI
import AppKit

func configureSettingsWindow() {
    DispatchQueue.main.async {
        guard let window = NSApp?.keyWindow else { return }
        if window.identifier != AppWindowIdentifier.settings {
            window.identifier = AppWindowIdentifier.settings
        }
        if window.tabbingMode != .disallowed {
            window.tabbingMode = .disallowed
        }
    }
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
    static let highlightSettingsGroup = Notification.Name("com.fuzee.settings.highlightGroup")
    static let toggleManageConnectionsSidebar = Notification.Name("com.fuzee.manageConnections.toggleSidebar")
}
