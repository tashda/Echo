import SwiftUI

extension NotificationSettingsView {
    var hasAnyEnabledNotifications: Bool {
        NotificationCategory.allCases.contains { preferences.isEnabled($0) }
    }

    var allEnabledBinding: Binding<Bool> {
        Binding(
            get: { hasAnyEnabledNotifications },
            set: { enabled in
                var updated = preferences
                if enabled {
                    updated.enableAll()
                } else {
                    updated.disableAll()
                }
                save(updated)
            }
        )
    }

    var deliveryBinding: Binding<NotificationDelivery> {
        Binding(
            get: { preferences.delivery },
            set: { newValue in
                var updated = preferences
                updated.delivery = newValue
                save(updated)
            }
        )
    }

    func groupBinding(for group: NotificationGroup) -> Binding<Bool> {
        Binding(
            get: { preferences.isGroupEnabled(group) },
            set: { enabled in
                var updated = preferences
                updated.setGroupEnabled(enabled, for: group)
                save(updated)
            }
        )
    }

    func categoryBinding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { preferences.isEnabled(category) },
            set: { enabled in
                var updated = preferences
                updated.markExplicitPreferences()
                updated.setEnabled(enabled, for: category)
                save(updated)
            }
        )
    }

    func save(_ preferences: NotificationPreferences) {
        var settings = projectStore.globalSettings
        settings.notificationPreferences = preferences
        Task {
            try? await projectStore.updateGlobalSettings(settings)
        }
    }
}
