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

            Section("Editor Font") {
                MonospacedFontPicker(
                    selectedFamily: Binding(
                        get: { projectStore.globalSettings.defaultEditorFontFamily },
                        set: { newValue in
                            var settings = projectStore.globalSettings
                            settings.defaultEditorFontFamily = newValue
                            Task { try? await projectStore.updateGlobalSettings(settings) }
                        }
                    ),
                    fontSize: projectStore.globalSettings.defaultEditorFontSize
                )

                PropertyRow(title: "Font Size") {
                    Picker("", selection: Binding(
                        get: { projectStore.globalSettings.defaultEditorFontSize },
                        set: { newValue in
                            var settings = projectStore.globalSettings
                            settings.defaultEditorFontSize = newValue
                            Task { try? await projectStore.updateGlobalSettings(settings) }
                        }
                    )) {
                        ForEach(Self.fontSizeOptions, id: \.self) { size in
                            Text(Self.fontSizeLabel(size)).tag(size)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                PropertyRow(title: "Enable Ligatures") {
                    Toggle("", isOn: Binding(
                        get: { projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true },
                        set: { newValue in
                            var settings = projectStore.globalSettings
                            settings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] = newValue
                            Task { try? await projectStore.updateGlobalSettings(settings) }
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                }
            }

            Section {
                EditorFontPreview(
                    fontName: projectStore.globalSettings.defaultEditorFontFamily,
                    fontSize: projectStore.globalSettings.defaultEditorFontSize,
                    ligatures: projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Constants

    private static let fontSizeOptions: [Double] = stride(from: 8.0, through: 24.0, by: 0.5).map { $0 }

    private static func fontSizeLabel(_ size: Double) -> String {
        size.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(size)),0 pt"
            : String(format: "%.1f pt", size).replacingOccurrences(of: ".", with: ",")
    }
}
