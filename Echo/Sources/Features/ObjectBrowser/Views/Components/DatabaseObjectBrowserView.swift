import SwiftUI

/// Database Explorer — hierarchical object list rendered inside a sidebar `List`.
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
    var onNewExtension: (() -> Void)? = nil

    @Environment(ProjectStore.self) var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(EnvironmentState.self) private var environmentState

    @State private var snapshotCache = ExplorerSnapshotCache()

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
                if newValue { expandedObjectIDs.insert(objectID) }
                else { expandedObjectIDs.remove(objectID) }
            }
        )
    }

    func typeExpandedBinding(for type: SchemaObjectInfo.ObjectType) -> Binding<Bool> {
        Binding(
            get: { expandedObjectGroups.contains(type) },
            set: { newValue in
                if newValue { expandedObjectGroups.insert(type) }
                else { expandedObjectGroups.remove(type) }
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

        Task {
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

        Group {
            if isSearching && snapshot.filteredCount == 0 {
                SearchEmptyStateView(query: searchText)
            } else {
                if !snapshot.pinned.isEmpty {
                    pinnedSection(snapshot.pinned)
                }

                ForEach(supportedObjectTypes, id: \.self) { type in
                    typeSection(type, snapshot.grouped[type] ?? [])
                }
            }
        }
        .onAppear { snapshotCache.update(with: input) }
        .onChange(of: input) { _, newValue in
            snapshotCache.update(with: newValue)
            autoExpandForSearch()
        }
    }

    private func autoExpandForSearch() {
        guard isSearching else { return }
        let snapshot = snapshotCache.data

        for (type, objects) in snapshot.grouped where !objects.isEmpty {
            expandedObjectGroups.insert(type)
        }

        if !snapshot.matchingChildObjectIDs.isEmpty {
            expandedObjectIDs.formUnion(snapshot.matchingChildObjectIDs)
        }
    }
}

private struct SearchEmptyStateView: View {
    let query: String
    private var formattedQuery: String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "your search" : "\"\(trimmed)\""
    }
    var body: some View {
        VStack(spacing: SpacingTokens.sm2) {
            Image(systemName: "magnifyingglass")
                .font(TypographyTokens.hero.weight(.semibold))
                .foregroundStyle(ColorTokens.Text.tertiary)
            Text("Nothing found for \(formattedQuery)")
                .font(TypographyTokens.standard)
                .foregroundStyle(ColorTokens.Text.secondary)
                .multilineTextAlignment(.center)
            Text("Try adjusting your filters or search terms.")
                .font(TypographyTokens.caption2)
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .padding(.vertical, SpacingTokens.xxl)
        .frame(maxWidth: .infinity)
    }
}
