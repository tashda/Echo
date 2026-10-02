import SwiftUI

/// The glass bubble that opens at once beside a hovered trail item (round 51, NM1): the server's
/// name, its product and, when there is something to say, what it is doing. It replaces the
/// system tooltip and never takes a click.
struct ServerRailNameBubble: View {
    let name: String
    let product: String
    var status: String?

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.nano) {
            Text(name)
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.primary)
            Text(product)
                .font(TypographyTokens.detail)
                .foregroundStyle(ColorTokens.Text.secondary)
            if let status {
                Text(status)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .glassEffect(.regular, in: .rect(cornerRadius: SpacingTokens.sm, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Where each trail item is, in the rail's own space, so the bubble can sit beside the hovered one
/// outside the pill's scroll view (which would cut it off).
struct ServerRailItemBoundsKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]

    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
