import SwiftUI
import Foundation

struct AppearanceSettingsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var themeManager: ThemeManager

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
            Picker("Appearance Mode", selection: appearanceModeBinding) {
                Text("System").tag(AppearanceMode.system)
                Text("Light").tag(AppearanceMode.light)
                Text("Dark").tag(AppearanceMode.dark)
            }
            .pickerStyle(.segmented)

            Text("Choose Light or Dark for a fixed appearance, or System to follow macOS automatically.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var accentColorSection: some View {
        Section("Accent Color") {
            Toggle("Use Server Color as Accent", isOn: $appModel.globalSettings.useServerColorAsAccent)
            
            ColorPicker("Custom Accent Color", selection: customAccentColorBinding)
                .disabled(appModel.globalSettings.useServerColorAsAccent)
            
            if appModel.globalSettings.useServerColorAsAccent {
                Text("When enabled, the accent color will change based on the active database connection.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var editorFontSection: some View {
        Section("Editor Font") {
            HStack {
                Text("Font Family")
                Spacer()
                TextField("Font Family", text: $appModel.globalSettings.defaultEditorFontFamily)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            Stepper(value: $appModel.globalSettings.defaultEditorFontSize, in: 8...24, step: 0.5) {
                HStack {
                    Text("Font Size")
                    Spacer()
                    Text("\(String(format: "%.1f", appModel.globalSettings.defaultEditorFontSize)) pt")
                        .foregroundStyle(.secondary)
                }
            }
            
            Toggle("Enable Ligatures", isOn: Binding(
                get: { appModel.globalSettings.fontLigatureOverrides[appModel.globalSettings.defaultEditorFontFamily] ?? true },
                set: { appModel.globalSettings.fontLigatureOverrides[appModel.globalSettings.defaultEditorFontFamily] = $0 }
            ))
        }
    }

    // MARK: - Bindings

    private var appearanceModeBinding: Binding<AppearanceMode> {
        Binding(
            get: { appModel.globalSettings.appearanceMode },
            set: { newValue in
                appModel.globalSettings.appearanceMode = newValue
                themeManager.applyAppearanceMode(newValue)
            }
        )
    }

    private var customAccentColorBinding: Binding<Color> {
        Binding(
            get: { themeManager.accentColor },
            set: { themeManager.setAccentColor($0) }
        )
    }
}
