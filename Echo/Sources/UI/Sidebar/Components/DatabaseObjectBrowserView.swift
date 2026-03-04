import SwiftUI

/// Database Explorer – hierarchical object list rendered in the explorer sidebar.
struct DatabaseObjectBrowserView: View {
    let database: DatabaseInfo
    let connection: SavedConnection
    @Binding var searchText: String
    @Binding var selectedSchemaName: String?
    @Binding var expandedObjectGroups: Set<SchemaObjectInfo.ObjectType>
    @Binding var expandedObjectIDs: Set<String>
    @Binding var pinnedObjectIDs: Set<String>
    @Binding var isPinnedSectionExpanded: Bool
    let scrollTo: (String, UnitPoint) -> Void
    
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @EnvironmentObject private var appModel: AppModel
    
    @State private var snapshotCache = ExplorerSnapshotCache()
    @State private var hoveredRowID: String?

    private var supportedObjectTypes: [SchemaObjectInfo.ObjectType] {
        SchemaObjectInfo.ObjectType.supported(for: connection.databaseType)
    }
    
    private var normalizedSearchQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }
    
    private var isSearching: Bool { normalizedSearchQuery != nil }
    
    private func displayName(for object: SchemaObjectInfo) -> String {
        selectedSchemaName == nil ? object.fullName : object.name
    }
    
    private func shouldShowColumns(for object: SchemaObjectInfo) -> Bool {
        object.type == .table || object.type == .view || object.type == .materializedView
    }
    
    private func togglePin(for object: SchemaObjectInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if pinnedObjectIDs.contains(object.id) {
                pinnedObjectIDs.remove(object.id)
            } else {
                pinnedObjectIDs.insert(object.id)
                isPinnedSectionExpanded = true
            }
        }
    }
    
    private func expansionBinding(for objectID: String) -> Binding<Bool> {
        Binding(
            get: { expandedObjectIDs.contains(objectID) },
            set: { newValue in
                if newValue {
                    expandedObjectIDs.insert(objectID)
                } else {
                    expandedObjectIDs.remove(objectID)
                }
            }
        )
    }
    
    private func revealTable(fullName: String) {
        guard let target = database.schemas
            .flatMap({ $0.objects.filter { $0.type == .table } })
            .first(where: { $0.fullName == fullName }) else { return }
        
        if let selected = selectedSchemaName, selected != target.schema {
            selectedSchemaName = nil
        }
        
        expandedObjectGroups.insert(.table)
        expandedObjectIDs.insert(target.id)
        
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.28)) {
                scrollTo(target.id, UnitPoint(x: 0.5, y: 0.2))
            }
        }
    }
    
    var body: some View {
        let input = SnapshotInput(
            database: database,
            normalizedQuery: normalizedSearchQuery,
            selectedSchemaName: selectedSchemaName,
            pinnedIDs: pinnedObjectIDs,
            supportedTypes: supportedObjectTypes
        )
        let snapshot = snapshotCache.data
        
        return Group {
            if isSearching && snapshot.filteredCount == 0 {
                SearchEmptyStateView(query: searchText)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if !snapshot.pinned.isEmpty {
                        pinnedSection(snapshot.pinned)
                    }
                    
                    ForEach(supportedObjectTypes, id: \.self) { type in
                        typeSection(type, snapshot.grouped[type] ?? [])
                    }
                }
                .environment(\.hoveredExplorerRowID, hoveredRowID)
                .environment(\.setHoveredExplorerRowID, { value in
                    Task { @MainActor in
                        if hoveredRowID != value { hoveredRowID = value }
                    }
                })
                .onHover { hovering in
                    Task { @MainActor in
                        if !hovering { hoveredRowID = nil }
                    }
                }
            }
        }
        .onAppear { snapshotCache.update(with: input) }
        .onChange(of: input) { _, newValue in snapshotCache.update(with: newValue) }
    }

    @ViewBuilder
    private func pinnedSection(_ pinnedList: [SchemaObjectInfo]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
    private func typeSection(_ type: SchemaObjectInfo.ObjectType, _ objects: [SchemaObjectInfo]) -> some View {
        let isExpanded = expandedObjectGroups.contains(type)
        VStack(alignment: .leading, spacing: 4) {
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

    private func sectionHeader(title: String, count: Int, isExpanded: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("\(count)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct SearchEmptyStateView: View {
    let query: String
    private var formattedQuery: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your search" : "\"\(trimmed)\""
    }
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text("Nothing found for \(formattedQuery)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try adjusting your filters or search terms.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}
