import SwiftUI

/// The controls that make a server recognisable (round 51, CU2 and WH2): its colour, and a symbol
/// or an emoji in place of its letters, with a preview. The trail's Customize Appearance popover
/// and the connection sheet both show this one view, so they cannot disagree.
struct ServerAppearanceControls: View {
    /// The server's name, for the letters and the preview.
    let name: String
    @Binding var colorHex: String
    @Binding var glyph: ServerRailGlyph?

    private static let glyphCell = SpacingTokens.lg + SpacingTokens.xxs
    private static let glyphColumns = 10

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sm) {
            preview
            section("Color") { colorRow }
            section("Symbol or emoji") { glyphGrid }
            Button("Reset to Automatic", action: reset)
                .buttonStyle(.link)
                .font(TypographyTokens.detail)
        }
    }

    // MARK: Preview

    private var preview: some View {
        HStack(spacing: SpacingTokens.xs) {
            ServerRailMark(
                monogram: ServerRailMonogram.make(from: name),
                glyph: glyph,
                color: color,
                weight: .bold,
                size: SpacingTokens.xl
            )
            .background(color.opacity(ServerAppearanceMetrics.previewTintOpacity), in: Circle())
            Text(name.isEmpty ? "Server" : name)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
                .lineLimit(1)
        }
    }

    // MARK: Colour

    private var color: Color { Color(hex: colorHex) ?? .accentColor }

    private var colorRow: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(ConnectionEditorView.colorPalette, id: \.self) { hex in
                let isSelected = colorHex.caseInsensitiveCompare(hex) == .orderedSame
                Button { colorHex = hex.uppercased() } label: {
                    Circle()
                        .fill(Color(hex: hex) ?? .accentColor)
                        .frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
                        .overlay {
                            if isSelected {
                                Circle()
                                    .strokeBorder(ColorTokens.accent, lineWidth: SpacingTokens.xxxs)
                                    .padding(-SpacingTokens.nano)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ObjectBrowserSidebarView.serverColorName(hex))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            ColorPicker("", selection: pickedColor, supportsOpacity: false)
                .labelsHidden()
        }
    }

    private var pickedColor: Binding<Color> {
        Binding(get: { color }, set: { colorHex = $0.toHex() ?? colorHex })
    }

    // MARK: Symbol or emoji

    private var glyphGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(Self.glyphCell), spacing: SpacingTokens.xxs), count: Self.glyphColumns),
            alignment: .leading,
            spacing: SpacingTokens.xxs
        ) {
            ForEach(ServerRailGlyph.symbols, id: \.self) { name in
                glyphButton(.symbol(name), label: name) {
                    Image(systemName: name).font(TypographyTokens.standard).foregroundStyle(ColorTokens.Text.primary)
                }
            }
            ForEach(ServerRailGlyph.emoji, id: \.self) { value in
                glyphButton(.emoji(value), label: value) { Text(value).font(TypographyTokens.prominent) }
            }
        }
    }

    private func glyphButton<Label: View>(_ choice: ServerRailGlyph, label: String, @ViewBuilder content: () -> Label) -> some View {
        let isSelected = glyph == choice
        return Button { glyph = isSelected ? nil : choice } label: {
            content()
                .frame(width: Self.glyphCell, height: Self.glyphCell)
                .background(
                    isSelected ? ColorTokens.accent.opacity(ServerAppearanceMetrics.selectedCellOpacity) : ColorTokens.Text.primary.opacity(ServerAppearanceMetrics.cellOpacity),
                    in: RoundedRectangle(cornerRadius: SpacingTokens.xxs2, style: .continuous)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            Text(title)
                .font(SidebarRowConstants.sectionHeadingFont)
                .foregroundStyle(ColorTokens.Text.secondary)
            content()
        }
    }

    /// Back to what Echo chooses by itself: the letters, in the first colour of the palette.
    private func reset() {
        glyph = nil
        colorHex = ConnectionEditorView.colorPalette.first ?? colorHex
    }
}

/// Opacities of the appearance controls' tints.
enum ServerAppearanceMetrics {
    static let previewTintOpacity = 0.2
    static let cellOpacity = 0.05
    static let selectedCellOpacity = 0.2
    /// Wide enough for ten grid cells and their gaps.
    static let popoverWidth = (SpacingTokens.lg + SpacingTokens.xxs) * 10 + SpacingTokens.xxs * 9 + SpacingTokens.md * 2
}
