import SwiftUI

extension AppearanceSettingsView {
    /// Round 28.3: the selection is rounded, 3pt by default; the owner asked for a setting.
    var selectionCornersRow: some View {
        PropertyRow(
            title: "Selection Corners",
            subtitle: "How round the corners of selected text are."
        ) {
            Picker("", selection: Binding(
                get: { EditorSelectionCorners(rawValue: projectStore.globalSettings.editorSelectionCornerRadius) ?? .three },
                set: { newValue in
                    var settings = projectStore.globalSettings
                    settings.editorSelectionCornerRadius = newValue.rawValue
                    Task { try? await projectStore.updateGlobalSettings(settings) }
                }
            )) {
                ForEach(EditorSelectionCorners.allCases, id: \.self) { Text($0.displayName).tag($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()
        }
    }
}
