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
            editorFontSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sections

    private var appearanceModeSection: some View {
        Section("Appearance Mode") {
            Picker("", selection: appearanceModeBinding) {
                Text("System").tag(AppearanceMode.system)
                Text("Light").tag(AppearanceMode.light)
                Text("Dark").tag(AppearanceMode.dark)
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accentColorSection: some View {
        Section("Accent Color") {
            Toggle("Use Server Color as Accent", isOn: Binding(
                get: { projectStore.globalSettings.useServerColorAsAccent },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.useServerColorAsAccent = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ))

            ColorPicker("Custom Accent Color", selection: customAccentColorBinding)
                .disabled(projectStore.globalSettings.useServerColorAsAccent)

            if projectStore.globalSettings.useServerColorAsAccent {
                Text("When enabled, the accent color will change based on the active database connection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
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

            Stepper(value: Binding(
                get: { projectStore.globalSettings.defaultEditorFontSize },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.defaultEditorFontSize = newValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            ), in: 8...24, step: 0.5) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(String(format: "%.1f", projectStore.globalSettings.defaultEditorFontSize)) pt")
                        .foregroundStyle(.secondary)
                }
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

    // MARK: - Bindings

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { projectStore.globalSettings.appearanceMode },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.appearanceMode = newValue
                Task { try? await projectStore.updateGlobalSettings(settings) }
                appearanceStore.applyAppearanceMode(newValue)
            }
        )
    }

    private var customAccentColorBinding: Binding<Color> {
        Binding(
            get: { appearanceStore.accentColor },
            set: { appearanceStore.setAccentColor($0) }
        )
    }
}
