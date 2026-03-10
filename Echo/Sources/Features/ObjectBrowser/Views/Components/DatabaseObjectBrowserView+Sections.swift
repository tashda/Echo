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
    }

    func sectionHeader(title: String, icon: String? = nil, count: Int, isExpanded: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(.tertiary)
                .frame(width: SidebarRowConstants.chevronWidth)
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: SidebarRowConstants.iconFrame)
            }
            Text(title)
                .font(TypographyTokens.standard)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text("\(count)")
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)

            Spacer(minLength: 4)
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}
