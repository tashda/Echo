import SwiftUI

/// Proves Echo Lab renders with the same tokens Echo ships.
struct TokensSamplePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.md) {
            HStack(spacing: SpacingTokens.sm) {
                swatch("Canvas", ColorTokens.Workspace.canvas)
                swatch("Card", ColorTokens.Workspace.card)
                swatch("Selected", ColorTokens.Sidebar.selectedFill)
                swatch("Hover", ColorTokens.Sidebar.hoverFill)
            }
            Text("Body text in the standard token")
                .font(TypographyTokens.standard)
        }
        .padding(SpacingTokens.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func swatch(_ name: String, _ color: Color) -> some View {
        VStack(spacing: SpacingTokens.xxs) {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(width: 96, height: 64)
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(ColorTokens.Workspace.cardEdge))
            Text(name).font(TypographyTokens.detail)
        }
    }
}
