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
    @EnvironmentObject private var environmentState: EnvironmentState
    
    @State private var snapshotCache = ExplorerSnapshotCache()
    @State private var hoveredRowID: String?

    private var supportedObjectTypes: [SchemaObjectInfo.ObjectType] {
        SchemaObjectInfo.ObjectType.supported(for: connection.databaseType)
    }
    
    var normalizedSearchQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }
    
    private var isSearching: Bool { normalizedSearchQuery != nil }
    
    func displayName(for object: SchemaObjectInfo) -> String {
        selectedSchemaName == nil ? object.fullName : object.name
    }
    
    func shouldShowColumns(for object: SchemaObjectInfo) -> Bool {
        object.type == .table || object.type == .view || object.type == .materializedView
    }
    
    func togglePin(for object: SchemaObjectInfo) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if pinnedObjectIDs.contains(object.id) {
                pinnedObjectIDs.remove(object.id)
            } else {
                pinnedObjectIDs.insert(object.id)
                isPinnedSectionExpanded = true
            }
        }
    }
    
    func expansionBinding(for objectID: String) -> Binding<Bool> {
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
    
    func revealTable(fullName: String) {
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
                .font(TypographyTokens.standard.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Try adjusting your filters or search terms.")
                .font(TypographyTokens.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, SpacingTokens.xxl)
        .frame(maxWidth: .infinity)
    }
}
