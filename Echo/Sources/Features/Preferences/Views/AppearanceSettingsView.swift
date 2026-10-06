import SwiftUI
import Foundation
import AppKit

struct AppearanceSettingsView: View {
    @Environment(ProjectStore.self) var projectStore
    @Environment(AppearanceStore.self) var appearanceStore

    var body: some View {
        Form {
            Section {
                PropertyRow(title: "Appearance") {
                    AppearanceModePicker(selection: appearanceModeBinding)
                }

                PropertyRow(
                    title: "Explorer Sidebar",
                    subtitle: "Choose the row density for the explorer sidebar."
                ) {
                    SidebarDensityPicker(selection: sidebarDensityBinding)
                }

                PropertyRow(
                    title: "Sidebar Icons",
                    subtitle: "Choose your preferred look for sidebar icons."
                ) {
                    SidebarIconPicker(selection: sidebarIconColorModeBinding)
                }

                if projectStore.globalSettings.sidebarIconColorMode == .monochrome {
                    PropertyRow(
                        title: "Monochrome Style",
                        subtitle: "Accent on open folders shows the path you've expanded."
                    ) {
                        Picker("", selection: projectStore.globalSettingBinding(\.sidebarMonochromeVariant)) {
                            ForEach(SidebarMonochromeVariant.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                PropertyRow(
                    title: "Section Dock Icons",
                    subtitle: "The icons under each server's name, apart from the tree's."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.sidebarDockIconStyle)) {
                        ForEach(SidebarDockIconStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Current Dock Icon",
                    subtitle: "The section you are in. The header's color falls back to the accent when the header has none."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.sidebarDockCurrentIconTint)) {
                        ForEach(SidebarDockCurrentIconTint.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Server Header",
                    subtitle: "How each server's name heads its card. Banner with Title puts a line of capitals over a large name; Plain is the name and product line alone."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.serverHeaderStyle)) {
                        ForEach(ServerHeaderStyle.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if projectStore.globalSettings.serverHeaderStyle == .titleBanner {
                    ServerHeaderLookRows()
                }

                PropertyRow(
                    title: "Server Header Color",
                    subtitle: "With the server's color, it also marks the rail, the server's tabs and the footer's server pill."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.serverHeaderColorSource)) {
                        ForEach(ServerHeaderColorSource.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Toolbar Project Button",
                    subtitle: "Show your account avatar or the project icon in the toolbar."
                ) {
                    Picker("", selection: toolbarProjectButtonStyleBinding) {
                        ForEach(ToolbarProjectButtonStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }
            }

            Section("Workspace") {
                PropertyRow(
                    title: "Animation Speed",
                    subtitle: "How fast panels, the rail and cards move. Reduce Motion in System Settings always wins."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.interfaceMotionSpeed)) {
                        ForEach(InterfaceMotionSpeed.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                PropertyRow(
                    title: "Spacing Between Panes",
                    subtitle: "Space between the server rail, the Explorer and the cards."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.workspaceGutter)) {
                        ForEach(WorkspaceGutter.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Card Corners",
                    subtitle: "Corner radius of the Explorer cards, the editor, results and other cards."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.workspaceCornerRadius)) {
                        ForEach(WorkspaceCornerRadius.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(
                    title: "Server Rail Size",
                    subtitle: "Size of the server buttons in the rail."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.railItemSize)) {
                        ForEach(RailItemSize.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
            }

            Section("Server Trail") {
                PropertyRow(
                    title: "When a Card Is Closed",
                    subtitle: "Move it into the server trail, or keep it in the tree as its header alone."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.closedCardDestination)) {
                        ForEach(ClosedCardDestination.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }

                PropertyRow(
                    title: "Show Recent Servers",
                    subtitle: "Servers you used lately but are not connected to, dimmed in the rail. Click one to connect."
                ) {
                    Toggle("", isOn: projectStore.globalSettingBinding(\.showsRecentServers))
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                PropertyRow(
                    title: "Number of Recent Servers",
                    subtitle: "How many recent servers the rail shows at most."
                ) {
                    Picker("", selection: projectStore.globalSettingBinding(\.recentServerCount)) {
                        ForEach(RecentServerCount.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                    .disabled(!projectStore.globalSettings.showsRecentServers)
                }
            }

            Section("Theme") {
                PropertyRow(title: "Accent Color") {
                    Picker("", selection: accentColorSourceBinding) {
                        ForEach(AccentColorSource.allCases, id: \.self) { source in
                            Text(source.displayName).tag(source)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                if projectStore.globalSettings.accentColorSource == .custom {
                    PropertyRow(title: "Color") {
                        AccentColorPalette(selection: customAccentColorHexBinding)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

}
