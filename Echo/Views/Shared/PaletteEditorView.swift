import SwiftUI

struct PaletteEditorView: View {
    @Binding var palette: SQLEditorPalette
    var isNameEditable: Bool = true

    var body: some View {
        Form {
            Section("Basics") {
                if isNameEditable {
                    TextField("Palette Name", text: nameBinding)
                } else {
                    HStack {
                        Text("Palette Name")
                        Spacer()
                        Text(palette.name)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Dark Palette", isOn: Binding(
                    get: { palette.isDark },
                    set: { palette.isDark = $0 }
                ))
                .toggleStyle(.switch)
            }

            Section("Background & Text") {
                colorPickerRow(label: "Editor Background", color: binding(for: \SQLEditorPalette.background))
                colorPickerRow(label: "Primary Text", color: binding(for: \SQLEditorPalette.text))
                colorPickerRow(label: "Selection", color: binding(for: \SQLEditorPalette.selection))
                colorPickerRow(label: "Current Line", color: binding(for: \SQLEditorPalette.currentLine))
            }

            Section("Gutter") {
                colorPickerRow(label: "Gutter Background", color: binding(for: \SQLEditorPalette.gutterBackground))
                colorPickerRow(label: "Gutter Text", color: binding(for: \SQLEditorPalette.gutterText))
                colorPickerRow(label: "Gutter Accent", color: binding(for: \SQLEditorPalette.gutterAccent))
            }

            Section("Tokens") {
                colorPickerRow(label: "Primary Keywords", color: binding(forTokens: \SQLEditorPalette.TokenColors.primaryKeyword))
                colorPickerRow(label: "Secondary Keywords", color: binding(forTokens: \SQLEditorPalette.TokenColors.secondaryKeyword))
                colorPickerRow(label: "Strings", color: binding(forTokens: \SQLEditorPalette.TokenColors.string))
                colorPickerRow(label: "Numbers", color: binding(forTokens: \SQLEditorPalette.TokenColors.number))
                colorPickerRow(label: "Comments", color: binding(forTokens: \SQLEditorPalette.TokenColors.comment))
                colorPickerRow(label: "Functions", color: binding(forTokens: \SQLEditorPalette.TokenColors.function))
                colorPickerRow(label: "Operators", color: binding(forTokens: \SQLEditorPalette.TokenColors.operatorSymbol))
                colorPickerRow(label: "Identifiers", color: binding(forTokens: \SQLEditorPalette.TokenColors.identifier))
                colorPickerRow(label: "Plain Text", color: binding(forTokens: \SQLEditorPalette.TokenColors.plain))
            }
        }
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { palette.name },
            set: { palette.name = $0 }
        )
    }

    private func binding(for keyPath: WritableKeyPath<SQLEditorPalette, ColorRepresentable>) -> Binding<Color> {
        Binding(
            get: { palette[keyPath: keyPath].color },
            set: { palette[keyPath: keyPath] = ColorRepresentable(color: $0) }
        )
    }

    private func binding(forTokens keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, ColorRepresentable>) -> Binding<Color> {
        Binding(
            get: { palette.tokens[keyPath: keyPath].color },
            set: { palette.tokens[keyPath: keyPath] = ColorRepresentable(color: $0) }
        )
    }

    @ViewBuilder
    private func colorPickerRow(label: String, color: Binding<Color>) -> some View {
        HStack {
            Text(label)
            Spacer()
            ColorPicker(label, selection: color, supportsOpacity: true)
                .labelsHidden()
                .frame(width: 120, alignment: .trailing)
        }
    }
}
