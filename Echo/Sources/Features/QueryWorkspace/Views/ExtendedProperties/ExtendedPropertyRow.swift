import SwiftUI

struct ExtendedPropertyRow: View {
    let property: ExtendedPropertyInfo
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sm) {
            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(property.name)
                    .font(TypographyTokens.standard.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.primary)

                Text(property.value.isEmpty ? "(empty)" : property.value)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(property.value.isEmpty ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
                    .lineLimit(3)
            }

            Spacer(minLength: SpacingTokens.xs)

            if isHovered {
                HStack(spacing: SpacingTokens.xxs) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(TypographyTokens.detail)
                    }
                    .buttonStyle(.plain)
                    .help("Edit property")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(ColorTokens.Status.error)
                    }
                    .buttonStyle(.plain)
                    .help("Delete property")
                }
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xs)
        .background(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(isHovered ? ColorTokens.Background.secondary : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
