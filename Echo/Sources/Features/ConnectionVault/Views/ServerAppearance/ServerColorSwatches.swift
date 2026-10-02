import SwiftUI

/// A server's colour (round 50, PC3): the thirty palette colours, each holding in light and in
/// dark appearance, and a colour well for any other. The grid lines up with the symbol grid under it.
struct ServerColorSwatches: View {
    @Binding var colorHex: String
    let cell: CGFloat
    let columns: Int

    private var current: String { ServerColorPalette.normalised(colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(cell), spacing: SpacingTokens.xxs), count: columns),
                alignment: .leading,
                spacing: SpacingTokens.xxs
            ) {
                ForEach(ServerColorPalette.all) { entry in
                    swatch(entry)
                }
            }
            HStack(spacing: SpacingTokens.xs) {
                ColorPicker("Any Color", selection: wellColor, supportsOpacity: false)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
        }
    }

    private func swatch(_ entry: ServerColor) -> some View {
        let isSelected = current == entry.lightHex
        return Button { colorHex = entry.lightHex } label: {
            Circle()
                .fill(ServerColorPalette.swiftUIColor(forStored: entry.lightHex) ?? .accentColor)
                .frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(ColorTokens.accent, lineWidth: SpacingTokens.xxxs)
                            .padding(-SpacingTokens.nano)
                    }
                }
                .frame(width: cell, height: cell)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(entry.name)
        .accessibilityLabel(entry.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The well shows the colour as it is now and saves what is picked as a plain hex, so a custom
    /// colour is the same in both appearances.
    private var wellColor: Binding<Color> {
        Binding(
            get: { ServerColorPalette.swiftUIColor(forStored: colorHex) ?? .accentColor },
            set: { colorHex = $0.toHex() ?? colorHex }
        )
    }
}
