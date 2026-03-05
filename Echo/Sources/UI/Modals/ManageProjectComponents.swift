import SwiftUI

struct StatCard: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)

            Text("\(count)")
                .font(TypographyTokens.hero.weight(.bold))

            Text(label)
                .font(TypographyTokens.detail)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(SpacingTokens.md)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
}

struct MetadataRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(TypographyTokens.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(TypographyTokens.caption2.weight(.medium))
        }
    }
}
