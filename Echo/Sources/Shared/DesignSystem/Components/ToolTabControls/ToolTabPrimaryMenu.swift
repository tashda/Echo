import SwiftUI

/// A main action with more than one thing to make (round 37.3, PA1): the same glass capsule as
/// `ToolTabPrimaryButton`, opening a menu (Add › Primary Key, Unique, Check).
struct ToolTabPrimaryMenu<Items: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            HStack(spacing: SpacingTokens.xxs2) {
                Image(systemName: systemImage).foregroundStyle(ColorTokens.accent)
                Text(title).foregroundStyle(ColorTokens.Text.secondary)
            }
            .font(TypographyTokens.standard.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, SpacingTokens.sm)
            .frame(height: LayoutTokens.ToolTab.controlHeight)
            .contentShape(.capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .glassEffect(.regular.interactive(), in: .capsule)
        .help(title)
        .accessibilityLabel(title)
    }
}
