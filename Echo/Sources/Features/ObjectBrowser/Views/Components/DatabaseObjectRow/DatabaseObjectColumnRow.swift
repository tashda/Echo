import SwiftUI

struct DatabaseObjectColumnRow: View {
    let column: ColumnInfo
    let isHovered: Bool
    let onCopyName: () -> Void
    let onRename: () -> Void
    let onDrop: () -> Void

    @State private var showDropAlert = false

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
        .padding(.leading, SidebarRowConstants.rowLeadingPadding + SidebarRowConstants.chevronWidth + SidebarRowConstants.iconTextSpacing)
        .padding(.vertical, SpacingTokens.xxxs)
        .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
        .background(
            RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
                .fill(ColorTokens.Text.primary.opacity(0.04))
                .opacity(isHovered ? 1 : 0)
        )
        .padding(.leading, CGFloat(ExplorerColumnMetrics.depth) * SidebarRowConstants.indentStep)
        .padding(.horizontal, SidebarRowConstants.rowOuterHorizontalPadding)
        .contextMenu {
            // Group 5: Copy
            Button {
                onCopyName()
            } label: {
                Label("Copy Name", systemImage: "doc.on.doc")
            }

            // Group 4: Edit
            Button {
                onRename()
            } label: {
                Label("Rename Column", systemImage: "character.cursor.ibeam")
            }

            Divider()

            // Group 10: Destructive
            Button(role: .destructive) {
                showDropAlert = true
            } label: {
                Label("Drop Column", systemImage: "trash")
            }
        }
        .alert("Drop Column?", isPresented: $showDropAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Drop", role: .destructive) {
                onDrop()
            }
        } message: {
            Text("Are you sure you want to drop \"\(column.name)\"? This action cannot be undone.")
        }
    }

}
