import SwiftUI

struct DatabaseObjectColumnRow: View {
    let column: ColumnInfo
    let accentColor: Color
    let isHovered: Bool
    let onCopyName: () -> Void
    let onRename: () -> Void
    let onDrop: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: ExplorerColumnMetrics.spacing) {
            let (iconName, iconColor): (String, Color) = {
                if column.isPrimaryKey {
                    return ("key.fill", accentColor)
                }
                if column.foreignKey != nil {
                    return ("arrow.turn.down.right", accentColor)
                }
                return ("circle.fill", Color.secondary)
            }()
            
            Image(systemName: iconName)
                .font(.system(size: iconName == "circle.fill" ? 8 : 10))
                .foregroundStyle(iconColor)
                .frame(width: ExplorerColumnMetrics.iconSize, height: ExplorerColumnMetrics.iconSize, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(column.name)
                    .font(TypographyTokens.detail)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let comment = column.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                    Text(comment)
                        .font(TypographyTokens.label)
                        .foregroundStyle(.secondary)
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
                .font(TypographyTokens.label.weight(.medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, SpacingTokens.xxs2)
                .padding(.vertical, SpacingTokens.xxxs)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.leading, ExplorerColumnMetrics.highlightExtension)
        .padding(.vertical, SpacingTokens.xxxs)
        .padding(.trailing, SpacingTokens.sm)
        .background(
            Group {
                if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor.opacity(0.08))
                } else {
                    Color.clear
                }
            }
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
