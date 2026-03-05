import SwiftUI
import AppKit

func configureSettingsWindowIdentifier() {
    DispatchQueue.main.async {
        guard let window = NSApp?.keyWindow else { return }
        if window.identifier != AppWindowIdentifier.settings {
            window.identifier = AppWindowIdentifier.settings
        }
    }
}

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
    static let highlightSettingsGroup = Notification.Name("com.fuzee.settings.highlightGroup")
}
