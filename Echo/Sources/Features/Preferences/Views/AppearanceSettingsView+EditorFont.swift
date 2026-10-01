import SwiftUI

extension AppearanceSettingsView {
    var editorFontSection: some View {
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

            PropertyRow(title: "Line Spacing") {
                Picker("", selection: Binding(
                    get: { projectStore.globalSettings.defaultEditorLineHeight },
                    set: { newValue in
                        var settings = projectStore.globalSettings
                        settings.defaultEditorLineHeight = newValue
                        Task { try? await projectStore.updateGlobalSettings(settings) }
                    }
                )) {
                    ForEach(Self.lineSpacingOptions, id: \.self) { spacing in
                        Text(Self.lineSpacingLabel(spacing)).tag(spacing)
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
    }

    static let fontSizeOptions: [Double] = stride(from: 8.0, through: 24.0, by: 0.5).map { $0 }

    static func fontSizeLabel(_ size: Double) -> String {
        size.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(size)),0 pt"
            : String(format: "%.1f pt", size).replacingOccurrences(of: ".", with: ",")
    }

    static let lineSpacingOptions: [Double] = [1.0, 1.2, 1.35, 1.55, 1.75, 2.0]

    static func lineSpacingLabel(_ spacing: Double) -> String {
        spacing == 1.0 ? "Single" : spacing.formatted(.number.precision(.fractionLength(0...2)))
    }
}
