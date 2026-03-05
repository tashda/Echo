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
    
    @Environment(\.hoveredExplorerRowID) private var hoveredExplorerRowID
    @Environment(\.setHoveredExplorerRowID) private var setHoveredExplorerRowID
    @State internal var hoveredColumnID: String?

    private var isHovered: Bool {
        hoveredExplorerRowID == object.id
    }

    private var canExpand: Bool {
        showColumns && !object.columns.isEmpty
    }
    
    internal var accentColor: Color {
        projectStore.globalSettings.accentColorSource == .connection ? connection.color : Color.accentColor
    }
    
    private var iconName: String {
        switch object.type {
        case .table:
            return "tablecells"
        case .view:
            return "eye"
        case .materializedView:
            return "eye.fill"
        case .function:
            return "function"
        case .trigger:
            return "bolt"
        case .procedure:
            return "gearshape"
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
        VStack(alignment: .leading, spacing: object.type == .trigger ? 6 : 0) {
            HStack(alignment: .center, spacing: 8) {
                if canExpand {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(TypographyTokens.label.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: iconName)
                            .font(TypographyTokens.caption2.weight(.medium))
                            .foregroundStyle(accentColor)

                        Text(displayName)
                            .font(TypographyTokens.standard)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if showColumns && !object.columns.isEmpty {
                            Text("\(object.columns.count)")
                                .font(TypographyTokens.detail.weight(.medium))
                                .foregroundStyle(accentColor)
                                .padding(.horizontal, SpacingTokens.xxs2)
                                .padding(.vertical, SpacingTokens.xxxs)
                                .background(accentColor.opacity(0.12), in: Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
            
            if object.type == .trigger {
                triggerMetadata
            }
        }
        .padding(.horizontal, SpacingTokens.sm)
        .padding(.vertical, SpacingTokens.xxs)
        .background(highlightBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            guard canExpand else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
        .onHover { hovering in
            if hovering {
                if hoveredExplorerRowID != object.id {
                    setHoveredExplorerRowID(object.id)
                }
            } else if isHovered {
                setHoveredExplorerRowID(nil)
            }
        }
        .contextMenu { contextMenuContent }
        .onDisappear {
            if isHovered {
                setHoveredExplorerRowID(nil)
            }
        }
    }
    
    @ViewBuilder
    private var triggerMetadata: some View {
        HStack(spacing: 6) {
            if let action = object.triggerAction, !action.isEmpty {
                Text(action)
                    .font(TypographyTokens.label.weight(.semibold))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, SpacingTokens.xs)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.12), in: Capsule())
            }
            if let table = object.triggerTable, !table.isEmpty {
                Button {
                    onTriggerTableTap?(table)
                } label: {
                    Text(table)
                        .font(TypographyTokens.label.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, SpacingTokens.xs)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.leading, SpacingTokens.lg)
    }
    
    private var highlightBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(accentColor.opacity(0.12))
            .opacity(isHovered || isExpanded ? 1 : 0)
            .allowsHitTesting(false)
            .animation(.easeOut(duration: 0.08), value: isHovered)
            .animation(.easeOut(duration: 0.18), value: isExpanded)
    }
    
}
