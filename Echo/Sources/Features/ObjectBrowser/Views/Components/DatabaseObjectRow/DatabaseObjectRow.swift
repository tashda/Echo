import SwiftUI

struct DatabaseObjectRow: View, Equatable {
    let object: SchemaObjectInfo
    let displayName: String
    let connection: SavedConnection
    let showColumns: Bool
    @Binding var isExpanded: Bool
    let isPinned: Bool
    let onTogglePin: () -> Void
    let onTriggerTableTap: ((String) -> Void)?
    
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @EnvironmentObject internal var environmentState: EnvironmentState
    
    @State private var isHovered = false
    @State internal var hoveredColumnID: String?

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
    }
    
    internal var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : Color.accentColor
    }
    
    private var iconName: String {
        switch object.type {
        case .table: return "tablecells"
        case .view: return "eye"
        case .materializedView: return "eye.fill"
        case .function: return "function"
        case .trigger: return "bolt"
        case .procedure: return "gearshape"
        }
    }

    private var iconColor: Color {
        switch object.type {
        case .table, .view, .materializedView: return .secondary
        case .function, .procedure: return .purple
        case .trigger: return .orange
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rowContent

            if isExpanded && canExpand {
                columnsList
            }
        }
    }

    static func == (lhs: DatabaseObjectRow, rhs: DatabaseObjectRow) -> Bool {
        lhs.object.id == rhs.object.id
            && lhs.displayName == rhs.displayName
            && lhs.showColumns == rhs.showColumns
            && lhs.isExpanded == rhs.isExpanded
            && lhs.isPinned == rhs.isPinned
    }
    
    private var rowContent: some View {
        HStack(alignment: .center, spacing: 8) {
            if canExpand {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)
            } else {
                Spacer().frame(width: SidebarRowConstants.chevronWidth)
            }

            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundStyle(iconColor)
                .frame(width: SidebarRowConstants.iconFrame)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(TypographyTokens.standard)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if object.type == .trigger, let table = object.triggerTable, !table.isEmpty {
                        Text("on")
                            .font(TypographyTokens.detail)
                            .foregroundStyle(.tertiary)
                        Button {
                            onTriggerTableTap?(table)
                        } label: {
                            Text(table)
                                .font(TypographyTokens.detail)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)
                }

                if let comment = object.comment?.trimmingCharacters(in: .whitespacesAndNewlines), !comment.isEmpty {
                    Text(comment)
                        .font(TypographyTokens.detail)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
#if os(macOS)
                        .help(comment)
#endif
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .background(highlightBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onHover { isHovered = $0 }
        .contextMenu { contextMenuContent }
    }
    
    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: SidebarRowConstants.hoverCornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.05))
            .opacity(isHovered ? 1 : 0)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.08), value: isHovered)
    }
    
}
