import SwiftUI

struct CountBadge: View {
    let count: Int
    var tint: Color = .secondary
    var opacity: Double = 0.06

    var body: some View {
        Text("\(count)")
            .font(TypographyTokens.label.weight(.semibold))
            .foregroundStyle(tint.opacity(0.8))
            .padding(.horizontal, SpacingTokens.xxs2)
            .padding(.vertical, SpacingTokens.xxxs)
            .background(Color.primary.opacity(opacity), in: Capsule())
    }
}
