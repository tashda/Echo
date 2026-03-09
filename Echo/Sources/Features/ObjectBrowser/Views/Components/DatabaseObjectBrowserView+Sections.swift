import SwiftUI

extension DatabaseObjectBrowserView {
    @ViewBuilder
    func pinnedSection(_ pinnedList: [SchemaObjectInfo]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) { isPinnedSectionExpanded.toggle() }
            } label: {
                sectionHeader(title: "PINNED", count: pinnedList.count, isExpanded: isPinnedSectionExpanded)
            }
            .buttonStyle(.plain)

            if isPinnedSectionExpanded {
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
                sectionHeader(title: type.pluralDisplayName.uppercased(), count: objects.count, isExpanded: isExpanded)
            }
            .buttonStyle(.plain)

            if isExpanded {
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
        }
    }

    func sectionHeader(title: String, count: Int, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(SidebarRowConstants.chevronFont)
                .foregroundStyle(.tertiary)
                .frame(width: SidebarRowConstants.chevronWidth)
            Text(title)
                .font(TypographyTokens.detail.weight(.medium))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(TypographyTokens.label)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, SidebarRowConstants.rowHorizontalPadding)
        .padding(.vertical, SidebarRowConstants.rowVerticalPadding)
        .contentShape(Rectangle())
    }
}
