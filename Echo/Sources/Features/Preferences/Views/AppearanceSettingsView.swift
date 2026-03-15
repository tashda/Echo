import SwiftUI
import Foundation
import AppKit

struct AppearanceSettingsView: View {
    @Environment(ProjectStore.self) private var projectStore
    @EnvironmentObject private var appearanceStore: AppearanceStore

    var body: some View {
        Form {
            appearanceModeSection
            accentColorSection
            sidebarSection
            editorFontSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private var appearanceModeSection: some View {
        Section("Appearance Mode") {
            AppearanceModePicker(selection: appearanceModeBinding)
        }
    }

    private var accentColorSection: some View {
        Section("Accent Color") {
            AccentColorSourceRow(selection: accentColorSourceBinding)


            if projectStore.globalSettings.accentColorSource == .custom {
                LabeledContent("Accent Color") {
                    AccentColorPalette(selection: customAccentColorHexBinding)
                }
            }
        }
    }

    private var sidebarSection: some View {
        Section("Sidebar") {
            Toggle("Colored sidebar icons", isOn: Binding(
                get: { projectStore.globalSettings.sidebarColoredIcons },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.sidebarColoredIcons = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))
        }
    }

    private var editorFontSection: some View {
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

            LabeledContent("Font Size") {
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
                .frame(minWidth: 100, idealWidth: 120, maxWidth: 160, alignment: .trailing)
            }

            Toggle("Enable Ligatures", isOn: Binding(
                get: { projectStore.globalSettings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] ?? true },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.fontLigatureOverrides[projectStore.globalSettings.defaultEditorFontFamily] = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))
        }
    }

    // MARK: - Constants

    private static let fontSizeOptions: [Double] = stride(from: 8.0, through: 24.0, by: 0.5).map { $0 }

    private static func fontSizeLabel(_ size: Double) -> String {
        size.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(size)),0 pt"
            : String(format: "%.1f pt", size).replacingOccurrences(of: ".", with: ",")
    }

    // MARK: - Bindings

    private var appearanceModeBinding: Binding<AppearanceMode> {
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

    private var accentColorSourceBinding: Binding<AccentColorSource> {
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

    private var customAccentColorHexBinding: Binding<String> {
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

