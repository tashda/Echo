import SwiftUI
import AppKit

extension NotificationSettingsView {
    var detailContent: some View {
        Form {
            overviewSection
            deliverySection
            ForEach(NotificationGroup.allCases) { group in
                categorySection(for: group)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    var overviewSection: some View {
        Section {
            HStack(alignment: .center, spacing: SpacingTokens.md) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                    Text("Echo Notifications")
                        .font(TypographyTokens.title3.weight(.semibold))

                    Text("Control how Echo appears in Notification Center and inside the app.")
                        .font(TypographyTokens.formDescription)
                        .foregroundStyle(ColorTokens.Text.secondary)
                }

                Spacer()
            }

            PropertyRow(
                title: "Allow notifications",
                subtitle: "Turn all Echo notifications on or off."
            ) {
                Toggle("", isOn: allEnabledBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
        } footer: {
            Text("Echo follows these preferences for both in-app toasts and native macOS notifications.")
        }
    }

    var deliverySection: some View {
        Section("Delivery") {
            PropertyRow(
                title: "Notification delivery",
                subtitle: preferences.delivery.displayDescription,
                info: "Choose whether Echo shows banners inside the app, through macOS Notification Center, or both."
            ) {
                Picker("", selection: deliveryBinding) {
                    ForEach(NotificationDelivery.allCases, id: \.self) { method in
                        Text(method.displayName)
                            .tag(method)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!allEnabledBinding.wrappedValue)
            }
        }
    }

    func categorySection(for group: NotificationGroup) -> some View {
        Section(group.displayName) {
            PropertyRow(
                title: "Allow \(group.displayName.lowercased()) notifications",
                subtitle: group.displayDescription
            ) {
                Toggle("", isOn: groupBinding(for: group))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .disabled(!allEnabledBinding.wrappedValue)
            }

            ForEach(group.categories) { category in
                PropertyRow(
                    title: category.displayName,
                    subtitle: category.displayDescription
                ) {
                    Toggle("", isOn: categoryBinding(for: category))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .disabled(!allEnabledBinding.wrappedValue)
                }
            }
        }
    }
}
