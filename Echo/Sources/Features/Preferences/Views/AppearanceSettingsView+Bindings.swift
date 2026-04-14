import SwiftUI

extension AppearanceSettingsView {

    var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { projectStore.globalSettings.appearanceMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.appearanceMode = newValue
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    appearanceStore.applyAppearanceMode(newValue)
                }
            }
        )
    }

    var sidebarDensityBinding: Binding<SidebarDensity> {
        Binding(
            get: { projectStore.globalSettings.sidebarDensity },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.sidebarDensity = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var sidebarIconColorModeBinding: Binding<SidebarIconColorMode> {
        Binding(
            get: { projectStore.globalSettings.sidebarIconColorMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.sidebarIconColorMode = newValue
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                }
            }
        )
    }

    var accentColorSourceBinding: Binding<AccentColorSource> {
        Binding(
            get: { projectStore.globalSettings.accentColorSource },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.accentColorSource = newValue
                let hex = settings.customAccentColorHex
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    switch newValue {
                    case .system, .connection:
                        appearanceStore.setAccentColor(nil)
                    case .custom:
                        if let hex, let color = Color(hex: hex) {
                            appearanceStore.setAccentColor(color)
                        }
                    }
                }
            }
        )
    }

    var toolbarProjectButtonStyleBinding: Binding<ToolbarProjectButtonStyle> {
        Binding(
            get: { projectStore.globalSettings.toolbarProjectButtonStyle },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.toolbarProjectButtonStyle = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

    var customAccentColorHexBinding: Binding<String> {
        Binding(
            get: { projectStore.globalSettings.customAccentColorHex ?? "" },
            set: { newHex in
                var settings = projectStore.globalSettings
                settings.customAccentColorHex = newHex.isEmpty ? nil : newHex
                Task {
                    try? await projectStore.updateGlobalSettings(settings)
                    if let color = Color(hex: newHex) {
                        appearanceStore.setAccentColor(color)
                    }
                }
            }
        )
    }
}
