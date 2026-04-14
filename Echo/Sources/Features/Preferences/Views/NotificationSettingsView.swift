import SwiftUI
import AppKit

struct NotificationSettingsView: View {
    @Environment(ProjectStore.self) internal var projectStore

    internal var preferences: NotificationPreferences {
        projectStore.globalSettings.notificationPreferences
    }

    var body: some View {
        detailContent
    }
}
