import SwiftUI

struct ExecutionPlanMissingIndexRow: View {
    let index: ExecutionPlanMissingIndex

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xs) {
            HStack(spacing: SpacingTokens.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.Status.warning)
                    .font(TypographyTokens.body)

                if let table = index.table {
                    Text(table)
                        .font(TypographyTokens.detail.weight(.semibold))
                }

                if let impact = index.impact {
                    Text("Impact: \(String(format: "%.1f%%", impact))")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                }
            }

            if !index.equalityColumns.isEmpty {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Equality:")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(index.equalityColumns.joined(separator: ", "))
                        .font(TypographyTokens.compact.monospaced())
                }
            }

            if !index.inequalityColumns.isEmpty {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Inequality:")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(index.inequalityColumns.joined(separator: ", "))
                        .font(TypographyTokens.compact.monospaced())
                }
            }

            if !index.includeColumns.isEmpty {
                HStack(spacing: SpacingTokens.xxs) {
                    Text("Include:")
                        .font(TypographyTokens.compact)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                    Text(index.includeColumns.joined(separator: ", "))
                        .font(TypographyTokens.compact.monospaced())
                }
            }

            Text(index.createStatement)
                .font(TypographyTokens.detail.monospaced())
                .textSelection(.enabled)
                .padding(SpacingTokens.xs)
                .background(ColorTokens.Background.secondary, in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(SpacingTokens.sm)
        .background(ColorTokens.Background.primary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ColorTokens.Text.quaternary.opacity(0.3), lineWidth: 1)
        )
    }
}
