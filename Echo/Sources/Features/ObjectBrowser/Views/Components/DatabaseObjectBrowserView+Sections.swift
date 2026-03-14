import SwiftUI

extension DatabaseObjectBrowserView {
    @ViewBuilder
    func pinnedSection(_ pinnedList: [SchemaObjectInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isPinnedSectionExpanded.toggle() }
            } label: {
                sectionHeader(title: "Pinned", icon: "pin.fill", count: pinnedList.count, isExpanded: isPinnedSectionExpanded)
            }
            .buttonStyle(.plain)

            if isPinnedSectionExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(pinnedList, id: \.id) { object in
                        DatabaseObjectRow(
                            object: object,
                            displayName: displayName(for: object),
                            connection: connection,
                            databaseName: database.name,
                            showColumns: shouldShowColumns(for: object),
                            isExpanded: expansionBinding(for: object.id),
                            isPinned: true,
                            onTogglePin: { togglePin(for: object) },
                            onTriggerTableTap: object.type == .trigger ? { revealTable(fullName: $0) } : nil
                        )
                        .id("pinned-\(object.id)")
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func typeSection(_ type: SchemaObjectInfo.ObjectType, _ objects: [SchemaObjectInfo]) -> some View {
        let isExpanded = expandedObjectGroups.contains(type)
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if isExpanded { expandedObjectGroups.remove(type) }
                    else { expandedObjectGroups.insert(type) }
                }
            } label: {
                sectionHeader(title: type.pluralDisplayName, icon: type.systemImage, count: objects.count, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(objects, id: \.id) { object in
                        DatabaseObjectRow(
                            object: object,
                            displayName: displayName(for: object),
                            connection: connection,
                            databaseName: database.name,
                            showColumns: shouldShowColumns(for: object),
                            isExpanded: expansionBinding(for: object.id),
                            isPinned: pinnedObjectIDs.contains(object.id),
                            onTogglePin: { togglePin(for: object) },
                            onTriggerTableTap: object.type == .trigger ? { revealTable(fullName: $0) } : nil
                        )
                        .equatable()
                        .id(object.id)
                    }
                }
                .padding(.leading, SidebarRowConstants.indentStep)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func sectionHeader(title: String, icon: String? = nil, count: Int, isExpanded: Bool) -> some View {
        let rowAccentColor = projectStore.globalSettings.accentColorSource == .connection ? connection.color : ColorTokens.accent
        return ExplorerSidebarRowChrome(isSelected: false, accentColor: rowAccentColor, style: .plain) {
            HStack(spacing: SidebarRowConstants.iconTextSpacing) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SidebarRowConstants.chevronFont)
                    .foregroundStyle(ColorTokens.Text.tertiary)
                    .frame(width: SidebarRowConstants.chevronWidth)

                if let icon {
                    Image(systemName: icon)
                        .font(SidebarRowConstants.iconFont)
                        .foregroundStyle(iconColor(for: title))
                        .frame(width: SidebarRowConstants.iconFrame)
                }

                Text(title)
                    .font(TypographyTokens.standard)
                    .foregroundStyle(ColorTokens.Text.primary)
                    .lineLimit(1)

                Spacer(minLength: SpacingTokens.xxxs)

                Text("\(count)")
                    .font(TypographyTokens.detail)
                    .foregroundStyle(ColorTokens.Text.tertiary)
            }
            .padding(.leading, SidebarRowConstants.rowHorizontalPadding)
            .padding(.trailing, SidebarRowConstants.rowTrailingPadding)
            .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func iconColor(for title: String) -> Color {
        let colored = projectStore.globalSettings.sidebarColoredIcons
        switch title {
        case SchemaObjectInfo.ObjectType.table.pluralDisplayName:
            return ExplorerSidebarPalette.objectGroupIconColor(for: .table, colored: colored)
        case SchemaObjectInfo.ObjectType.view.pluralDisplayName,
             SchemaObjectInfo.ObjectType.materializedView.pluralDisplayName:
            return ExplorerSidebarPalette.objectGroupIconColor(for: .view, colored: colored)
        case SchemaObjectInfo.ObjectType.function.pluralDisplayName,
             SchemaObjectInfo.ObjectType.procedure.pluralDisplayName,
             SchemaObjectInfo.ObjectType.trigger.pluralDisplayName:
            return ExplorerSidebarPalette.objectGroupIconColor(for: .function, colored: colored)
        case SchemaObjectInfo.ObjectType.extension.pluralDisplayName:
            return ExplorerSidebarPalette.objectGroupIconColor(for: .extension, colored: colored)
        default:
            return ExplorerSidebarPalette.monochrome
        }
    }
}
