import SwiftUI

struct NotificationSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore

    private var preferences: NotificationPreferences {
        projectStore.globalSettings.notificationPreferences
    }

    var body: some View {
        Form {
            deliverySection
            categoriesSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Delivery

    private var deliverySection: some View {
        Section("Delivery Method") {
            Picker("Deliver notifications via", selection: deliveryBinding) {
                ForEach(NotificationDelivery.allCases, id: \.self) { method in
                    Text(method.displayName).tag(method)
                }
            }
            .pickerStyle(.radioGroup)
        }
    }

    private var deliveryBinding: Binding<NotificationDelivery> {
        Binding(
            get: { preferences.delivery },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.notificationPreferences.delivery = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        Section("Notification Categories") {
            ForEach(NotificationGroup.allCases) { group in
                DisclosureGroup {
                    ForEach(group.categories) { category in
                        Toggle(category.displayName, isOn: categoryBinding(for: category))
                    }
                } label: {
                    Label(group.displayName, systemImage: group.systemImage)
                }
            }
        }
    }

    private func categoryBinding(for category: NotificationCategory) -> Binding<Bool> {
        Binding(
            get: { preferences.isEnabled(category) },
            set: { enabled in
                var settings = projectStore.globalSettings
                settings.notificationPreferences.setEnabled(enabled, for: category)
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }
}
