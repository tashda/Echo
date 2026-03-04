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
                    .font(.system(size: 11))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let comment = column.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                    Text(comment)
                        .font(.system(size: 10))
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

            Text(formatDataType(column.dataType))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .padding(.leading, ExplorerColumnMetrics.highlightExtension)
        .padding(.vertical, 2)
        .padding(.trailing, 12)
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
    
    private func formatDataType(_ dataType: String) -> String {
        var formatted = dataType
        if formatted.contains("with time zone") {
            formatted = formatted.replacingOccurrences(of: " with time zone", with: "tz")
        }
        if formatted.contains("without time zone") {
            formatted = formatted.replacingOccurrences(of: " without time zone", with: "")
        }
        return formatted
    }
}
