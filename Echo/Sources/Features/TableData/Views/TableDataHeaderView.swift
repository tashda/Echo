import SwiftUI

struct TableDataHeaderView: View {
    let columns: [TableDataColumn]
    let isEditMode: Bool

    private let columnMinWidth: CGFloat = 120
    private let rowNumberWidth: CGFloat = 50

    var body: some View {
        HStack(spacing: SpacingTokens.none) {
            // Row number header
            Text("#")
                .font(TypographyTokens.detail.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary)
                .frame(width: rowNumberWidth, alignment: .center)

            if isEditMode {
                // Delete column header placeholder
                Color.clear
                    .frame(width: 32)
            }

            ForEach(columns) { column in
                VStack(alignment: .leading, spacing: SpacingTokens.xxs2) {
                    Text(column.name)
                        .font(TypographyTokens.detail.weight(.semibold))
                        .foregroundStyle(ColorTokens.Text.primary)
                        .lineLimit(1)

                    Text(column.dataType)
                        .font(TypographyTokens.micro)
                        .foregroundStyle(ColorTokens.Text.tertiary)
                        .lineLimit(1)
                }
                .frame(minWidth: columnMinWidth, alignment: .leading)
                .padding(.horizontal, SpacingTokens.xs)

                if column.isPrimaryKey {
                    Image(systemName: "key.fill")
                        .font(TypographyTokens.micro)
                        .foregroundStyle(ColorTokens.Status.warning)
                }
            }

            Spacer(minLength: SpacingTokens.none)
        }
        .padding(.vertical, SpacingTokens.xs)
        .background(ColorTokens.Background.secondary)
    }
}
