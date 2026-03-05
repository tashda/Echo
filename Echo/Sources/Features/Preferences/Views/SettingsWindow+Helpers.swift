import SwiftUI

#if os(macOS)
import AppKit

func configureSettingsWindowIdentifier() {
    DispatchQueue.main.async {
        guard let window = NSApp?.keyWindow else { return }
        if window.identifier != AppWindowIdentifier.settings {
            window.identifier = AppWindowIdentifier.settings
        }
    }
}
#endif

extension Notification.Name {
    static let openSettingsSection = Notification.Name("com.fuzee.settings.openSection")
}
