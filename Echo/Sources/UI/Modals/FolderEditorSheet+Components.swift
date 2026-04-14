import SwiftUI

extension FolderEditorSheet {

    // MARK: - Icon Palette

    var iconPaletteView: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            ForEach(availableIcons, id: \.self) { iconName in
                iconSwatch(name: iconName, isSelected: selectedIcon == iconName)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedIcon = iconName
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    func iconSwatch(name: String, isSelected: Bool) -> some View {
        Image(systemName: name)
            .font(TypographyTokens.prominent)
            .frame(width: 26, height: 26)
            .foregroundStyle(isSelected ? Color.white : ColorTokens.Text.secondary)
            .background(isSelected ? ColorTokens.accent : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(Rectangle())
    }

    // MARK: - Color Palette

    var colorPaletteView: some View {
        HStack(spacing: SpacingTokens.xs) {
            ForEach(FolderIdentityPalette.defaults, id: \.self) { hex in
                let swatch = Color(hex: hex) ?? ColorTokens.accent
                colorSwatch(color: swatch, isSelected: selectedColorHex == hex)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedColorHex = hex }
                    }
            }

            ColorPicker("", selection: folderColorBinding, supportsOpacity: false)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    func colorSwatch(color: Color, isSelected: Bool) -> some View {
        Circle().fill(color).frame(width: SpacingTokens.md2, height: SpacingTokens.md2)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(TypographyTokens.label.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .overlay(Circle().strokeBorder(ColorTokens.Text.primary.opacity(0.15), lineWidth: 0.5))
            .contentShape(Circle())
    }
}
