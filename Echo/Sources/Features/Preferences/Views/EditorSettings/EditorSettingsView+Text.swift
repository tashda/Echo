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

            PropertyRow(title: "Size", resetAction: projectStore.resetAction(\.defaultEditorFontSize)) {
                HStack(spacing: SpacingTokens.xxs) {
                    TextField("", value: fontSizeBinding, format: .number.precision(.fractionLength(0)))
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: SpacingTokens.xl)
                    Text("pt").foregroundStyle(ColorTokens.Text.secondary)
                    Stepper("", value: fontSizeBinding, in: Self.fontSizeRange, step: 1)
                        .labelsHidden()
                }
            }

            PropertyRow(title: "Line Height", resetAction: projectStore.resetAction(\.defaultEditorLineHeight)) {
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

    /// Round 43.3 (NU0): whole sizes in a stepper with its unit; typing is allowed.
    static let fontSizeRange: ClosedRange<Double> = 8...24

    var fontSizeBinding: Binding<Double> {
        Binding(
            get: { projectStore.globalSettings.defaultEditorFontSize.rounded() },
            set: { newValue in
                var settings = projectStore.globalSettings
                settings.defaultEditorFontSize = min(max(newValue.rounded(), Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
                Task { try? await projectStore.updateGlobalSettings(settings) }
            }
        )
    }

}
