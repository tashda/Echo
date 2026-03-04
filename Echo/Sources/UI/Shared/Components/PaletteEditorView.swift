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
                tokenEditorRow(label: "Keywords", keyPath: \.keyword)
                tokenEditorRow(label: "Strings", keyPath: \.string)
                tokenEditorRow(label: "Numbers", keyPath: \.number)
                tokenEditorRow(label: "Comments", keyPath: \.comment)
                tokenEditorRow(label: "Functions", keyPath: \.function)
                tokenEditorRow(label: "Operators", keyPath: \.operatorSymbol)
                tokenEditorRow(label: "Identifiers", keyPath: \.identifier)
                tokenEditorRow(label: "Plain Text", keyPath: \.plain)
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

    private func binding(forTokens keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Color> {
        Binding(
            get: { palette.tokens[keyPath: keyPath].swiftColor },
            set: { newValue in
                var style = palette.tokens[keyPath: keyPath]
                style.color = ColorRepresentable(color: newValue)
                palette.tokens[keyPath: keyPath] = style
            }
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

    @ViewBuilder
    private func tokenEditorRow(
        label: String,
        keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                ColorPicker(
                    label,
                    selection: binding(forTokens: keyPath),
                    supportsOpacity: true
                )
                .labelsHidden()
                .frame(width: 120, alignment: .trailing)
            }

            HStack(spacing: 16) {
                Spacer()
                Toggle("Bold", isOn: boldBinding(for: keyPath))
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                Toggle("Italic", isOn: italicBinding(for: keyPath))
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
            }
            .font(.caption)
            .padding(.trailing, 4)
        }
        .padding(.vertical, 2)
    }

    private func boldBinding(for keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Bool> {
        Binding(
            get: { palette.tokens[keyPath: keyPath].isBold },
            set: { newValue in
                var style = palette.tokens[keyPath: keyPath]
                style.isBold = newValue
                palette.tokens[keyPath: keyPath] = style
            }
        )
    }

    private func italicBinding(for keyPath: WritableKeyPath<SQLEditorPalette.TokenColors, SQLEditorPalette.TokenStyle>) -> Binding<Bool> {
        Binding(
            get: { palette.tokens[keyPath: keyPath].isItalic },
            set: { newValue in
                var style = palette.tokens[keyPath: keyPath]
                style.isItalic = newValue
                palette.tokens[keyPath: keyPath] = style
            }
        )
    }
}
