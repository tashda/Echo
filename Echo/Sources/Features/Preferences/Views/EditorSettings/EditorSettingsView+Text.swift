import SwiftUI

extension EditorSettingsView {
    var textSection: some View {
        Section("Text") {
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

            PropertyRow(title: "Size") {
                Picker("", selection: Binding(
                    get: { projectStore.globalSettings.defaultEditorFontSize.rounded() },
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

            PropertyRow(title: "Line Height") {
                Picker("", selection: Binding(
                    get: { EditorLineHeight.nearest(to: projectStore.globalSettings.defaultEditorLineHeight) },
                    set: { newValue in
                        var settings = projectStore.globalSettings
                        settings.defaultEditorLineHeight = newValue.rawValue
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                )) {
                    ForEach(EditorLineHeight.allCases, id: \.self) { height in
                        Text(height.displayName).tag(height)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            PropertyRow(title: "Ligatures") {
                Toggle("", isOn: Binding(
                    get: { projectStore.globalSettings.ligaturesEnabled(for: projectStore.globalSettings.defaultEditorFontFamily) },
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
    }

    /// Round 28.11 (FS1): whole sizes, “13 pt”.
    static let fontSizeOptions: [Double] = Array(stride(from: 8.0, through: 24.0, by: 1.0))

    static func fontSizeLabel(_ size: Double) -> String {
        "\(Int(size)) pt"
    }

}
