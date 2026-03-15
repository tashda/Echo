import SwiftUI

struct DatabaseObjectColumnRow: View {
    let column: ColumnInfo
    let isHovered: Bool
    let onCopyName: () -> Void
    let onRename: () -> Void
    let onDrop: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: ExplorerColumnMetrics.spacing) {
            let (iconName, iconColor, iconSize): (String, Color, CGFloat) = {
                if column.isPrimaryKey {
                    return ("key.fill", Color.orange, 10)
                }
                if column.foreignKey != nil {
                    return ("arrow.turn.down.right", ColorTokens.Status.info, 10)
                }
                return ("circle.fill", ColorTokens.Text.quaternary, 5)
            }()

            Image(systemName: iconName)
                .font(.system(size: iconSize))
                .foregroundStyle(iconColor)
                .frame(width: ExplorerColumnMetrics.iconSize, height: ExplorerColumnMetrics.iconSize, alignment: .center)

            VStack(alignment: .leading, spacing: SpacingTokens.xxxs) {
                Text(column.name)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                if let comment = column.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                    Text(comment)
                        .font(TypographyTokens.label)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
#if os(macOS)
                        .help(comment)
#endif
                }
            }

            Spacer()

            Text(EchoFormatters.abbreviatedSQLType(column.dataType))
                .font(TypographyTokens.label)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.leading, ExplorerColumnMetrics.highlightExtension)
        .padding(.vertical, SpacingTokens.xxxs)
        .padding(.trailing, SpacingTokens.sm)
        .background(
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.04))
                .opacity(isHovered ? 1 : 0)
        )
        .padding(.leading, max(ExplorerColumnMetrics.contentLeading - ExplorerColumnMetrics.highlightExtension, 0))
        .contentShape(Rectangle())
        .contextMenu {
            Button("Copy Name") {
                onCopyName()
            }
            Button("Rename Column…") {
                onRename()
            }
            Button("Drop Column", role: .destructive) {
                onDrop()
            }
        }
    }

}
