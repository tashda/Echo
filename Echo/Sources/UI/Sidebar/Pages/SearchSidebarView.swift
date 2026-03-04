import SwiftUI
import Combine
import EchoSense

struct SearchSidebarView: View {
    @Environment(ProjectStore.self) private var projectStore
    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(TabStore.self) private var tabStore
    
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var viewModel = SearchSidebarViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var didRestoreCache = false
    @State private var activeCacheKey: SearchSidebarContextKey?
    @State private var isFilterPopoverPresented = false

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            content
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            if !didRestoreCache {
                didRestoreCache = true
                syncContext(forceRestore: true)
            } else {
                syncContext()
            }
            viewModel.setQueryTabProvider { [weak appModel] in
                queryTabSnapshots(from: appModel)
            }
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: connectionStore.selectedConnectionID) { _, _ in syncContext() }
        .onChange(of: activeSession?.id) { _, _ in syncContext() }
        .onChange(of: activeSession?.selectedDatabaseName) { _, _ in syncContext() }
        .onReceive(viewModel.$query.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$selectedCategories.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$results) { _ in cacheState() }
        .onReceive(viewModel.$errorMessage.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$isSearching.removeDuplicates()) { _ in cacheState() }
        .onChange(of: tabStore.tabs.map(\.id)) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: tabStore.activeTabId) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onDisappear { persistActiveCache() }
    }

    private var requiresDatabaseContext: Bool {
        viewModel.selectedCategories.contains { $0 != .queryTabs }
    }

    private var hasQueryTabFilter: Bool {
        viewModel.selectedCategories.contains(.queryTabs)
    }

    private var isSearchFieldDisabled: Bool {
        guard requiresDatabaseContext else { return false }
        guard let session = activeSession else { return true }
        return session.selectedDatabaseName?.isEmpty != false
    }

    private var isFilterActive: Bool {
        viewModel.selectedCategories.count != SearchSidebarCategory.allCases.count
    }

    private var searchBar: some View {
        SidebarSearchBar(
            placeholder: "Search tables, views, query tabs...",
            text: $viewModel.query,
            isDisabled: isSearchFieldDisabled,
            showsClearButton: !viewModel.query.isEmpty,
            onClear: { viewModel.clearQuery() },
            focusBinding: $isSearchFieldFocused,
            clearShortcut: .cancelAction
        ) {
            filterButton
        }
    }

    private var filterButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(
                    isFilterActive
                        ? Color.accentColor
                        : Color.secondary.opacity(0.6)
                )
                .padding(2)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(isFilterActive ? 0.18 : 0))
                )
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(filterLabel)
        .popover(isPresented: $isFilterPopoverPresented, arrowEdge: .top) {
            SearchFilterPopoverView(
                selectedCategories: $viewModel.selectedCategories,
                onSelectAll: {
                    viewModel.resetFilters()
                },
                onClearAll: {
                    viewModel.selectedCategories.removeAll()
                }
            )
            .padding(14)
            .frame(minWidth: 220)
        }
    }

    private var filterLabel: String {
        let total = SearchSidebarCategory.allCases.count
        let selected = viewModel.selectedCategories.count

        if selected == 0 {
            return "No Filters"
        }
        if selected == total {
            return "All Objects"
        }
        if selected == 1, let first = viewModel.selectedCategories.first {
            return first.displayName
        }
        return "\(selected) Filters"
    }

    @ViewBuilder
    private var content: some View {
        let requiresDatabase = requiresDatabaseContext
        let hasQueryTabs = hasQueryTabFilter

        if requiresDatabase && !hasQueryTabs && activeSession == nil {
            SearchPlaceholderView(
                systemImage: "externaldrive",
                title: "No active connection",
                subtitle: "Connect to a database server to start searching."
            )
        } else if requiresDatabase && !hasQueryTabs && activeSession?.selectedDatabaseName?.isEmpty != false {
            SearchPlaceholderView(
                systemImage: "cylinder",
                title: "Select a database",
                subtitle: "Choose a database for the current connection to search its objects."
            )
        } else if viewModel.selectedCategories.isEmpty {
            SearchPlaceholderView(
                systemImage: "slider.horizontal.3",
                title: "Enable at least one filter",
                subtitle: "Pick one or more object types to include in the search."
            )
        } else if viewModel.trimmedQuery.count < viewModel.minimumSearchLength {
            SearchPlaceholderView(
                systemImage: "text.magnifyingglass",
                title: "Search the selected database",
                subtitle: "Enter at least \(viewModel.minimumSearchLength) characters to see results."
            )
        } else if viewModel.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                Text("Searching...")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if let error = viewModel.errorMessage {
            SearchPlaceholderView(
                systemImage: "exclamationmark.triangle",
                title: "Search failed",
                subtitle: error,
                actionTitle: "Try Again",
                action: { viewModel.retryLastSearch() }
            )
        } else if viewModel.results.isEmpty {
            SearchPlaceholderView(
                systemImage: "questionmark",
                title: "No matches",
                subtitle: "No objects match your query. Try different keywords or filters."
            )
        } else {
            resultsList
        }
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12, pinnedViews: .sectionHeaders) {
                ForEach(groupedResults, id: \.category) { group in
                    Section {
                        VStack(spacing: 8) {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: result,
                                    query: viewModel.trimmedQuery,
                                    onSelect: { handleResultTap(result) },
                                    fetchDefinition: definitionFetcher(for: result)
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        .padding(.bottom, 4)
                    } header: {
                        SidebarStickySectionHeader(
                            title: group.category.displayName,
                            count: group.results.count,
                            isExpanded: true,
                            coordinateSpaceName: SearchSidebarConstants.scrollSpace,
                            onTap: nil
                        )
                    }
                    .id("search-section-\(group.category.rawValue)")
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .coordinateSpace(name: SearchSidebarConstants.scrollSpace)
    }

    private var groupedResults: [(category: SearchSidebarCategory, results: [SearchSidebarResult])]
    {
        let groups = Dictionary(grouping: viewModel.results, by: \.category)
        return SearchSidebarCategory.allCases.compactMap { category in
            guard let results = groups[category] else { return nil }
            return (category, results)
        }
    }

    private func definitionFetcher(for result: SearchSidebarResult) -> (() async throws -> String)? {
        guard let payload = result.payload else { return nil }
        guard let session = activeSession else { return nil }

        switch payload {
        case .schemaObject(let schema, let name, let type):
            switch type {
            case .view, .materializedView, .function, .procedure, .trigger:
                return {
                    try await session.session.getObjectDefinition(
                        objectName: name,
                        schemaName: schema,
                        objectType: type
                    )
                }
            default:
                return nil
            }
        case .function(let schema, let name):
            return {
                try await session.session.getObjectDefinition(
                    objectName: name,
                    schemaName: schema,
                    objectType: .function
                )
            }
        case .procedure(let schema, let name):
            return {
                try await session.session.getObjectDefinition(
                    objectName: name,
                    schemaName: schema,
                    objectType: .procedure
                )
            }
        case .trigger(let schema, _, let name):
            return {
                try await session.session.getObjectDefinition(
                    objectName: name,
                    schemaName: schema,
                    objectType: .trigger
                )
            }
        default:
            return nil
        }
    }

    private var activeSession: ConnectionSession? {
        if let selectedID = connectionStore.selectedConnectionID,
           let session = appModel.sessionManager.sessionForConnection(selectedID) {
            return session
        }
        return appModel.sessionManager.activeSession
    }

    private func syncContext(forceRestore: Bool = false) {
        let session = activeSession
        let newKey = session.map { SearchSidebarContextKey(connectionID: $0.connection.id, databaseName: $0.selectedDatabaseName) }

        if forceRestore || newKey != activeCacheKey {
            persistActiveCache()
            activeCacheKey = newKey
            restoreCache(for: newKey)
        }

        if let session {
            viewModel.updateContext(
                databaseSession: session.session,
                databaseName: session.selectedDatabaseName,
                databaseType: session.connection.databaseType
            )
        } else {
            viewModel.updateContext(databaseSession: nil, databaseName: nil, databaseType: nil)
        }
    }

    private func restoreCache(for key: SearchSidebarContextKey?) {
        let cache = key.flatMap { appModel.searchSidebarCaches[$0] } ?? SearchSidebarCache()
        viewModel.restore(from: cache)
    }

    private func persistActiveCache() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        guard let key = activeCacheKey else { return }
        let snapshot = viewModel.snapshot()
        if appModel.searchSidebarCaches[key] != snapshot {
            appModel.searchSidebarCaches[key] = snapshot
        }
    }

    private func cacheState() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        guard let key = activeCacheKey else { return }
        let snapshot = viewModel.snapshot()
        if appModel.searchSidebarCaches[key] != snapshot {
            appModel.searchSidebarCaches[key] = snapshot
        }
    }

    private func handleResultTap(_ result: SearchSidebarResult, openInNewTab: Bool = false) {
        guard let session = activeSession,
              let databaseName = session.selectedDatabaseName,
              !databaseName.isEmpty,
              let payload = result.payload else {
            return
        }

        switch payload {
        case .schemaObject(let schema, let name, let type):
            switch type {
            case .table:
                if openInNewTab {
                    openQueryPreview(forTable: name, schema: schema, session: session)
                } else {
                    focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: .table)
                }
            case .view, .materializedView, .function, .procedure, .trigger:
                if openInNewTab {
                    openDefinition(for: name, schema: schema, type: type, in: session)
                } else {
                    openDefinition(for: name, schema: schema, type: type, in: session)
                }
            }

        case .column(let schema, let table, let column):
            if openInNewTab {
                openQueryPreview(forColumn: column, table: table, schema: schema, session: session)
            } else {
                focusExplorer(on: session, database: databaseName, schema: schema, objectName: table, columnName: column, objectType: .table)
            }

        case .index(let schema, let table, _):
            if openInNewTab {
                openQueryPreview(forTable: table, schema: schema, session: session)
            } else {
                openStructure(for: session, schema: schema, table: table, focus: .indexes)
            }

        case .foreignKey(let schema, let table, _):
            if openInNewTab {
                openQueryPreview(forTable: table, schema: schema, session: session)
            } else {
                openStructure(for: session, schema: schema, table: table, focus: .relations)
            }

        case .function(let schema, let name):
            openDefinition(for: name, schema: schema, type: .function, in: session)
        case .procedure(let schema, let name):
            openDefinition(for: name, schema: schema, type: .procedure, in: session)

        case .trigger(let schema, _, let name):
            openDefinition(for: name, schema: schema, type: .trigger, in: session)

        case .queryTab(let tabID, let connectionSessionID):
            appModel.sessionManager.setActiveSession(connectionSessionID)
            tabStore.activeTabId = tabID
        }
    }

    private func openStructure(for session: ConnectionSession, schema: String, table: String, focus: TableStructureSection?) {
        let object = SchemaObjectInfo(name: table, schema: schema, type: .table)
        appModel.openStructureTab(for: session, object: object, focus: focus)
    }

    private func openQueryPreview(forTable table: String, schema: String, session: ConnectionSession) {
        let qualified = qualifiedTableName(schema: schema, table: table, databaseType: session.connection.databaseType)
        let sql: String
        switch session.connection.databaseType {
        case .microsoftSQL:
            sql = "SELECT TOP 200 *\nFROM \(qualified);"
        default:
            sql = "SELECT *\nFROM \(qualified)\nLIMIT 200;"
        }
        appModel.openQueryTab(for: session, presetQuery: sql)
    }

    private func openQueryPreview(forColumn column: String, table: String, schema: String, session: ConnectionSession) {
        let databaseType = session.connection.databaseType
        let qualified = qualifiedTableName(schema: schema, table: table, databaseType: databaseType)
        let quotedColumn = quoteIdentifier(column, databaseType: databaseType)
        let sql: String
        switch databaseType {
        case .microsoftSQL:
            sql = "SELECT TOP 200 \(quotedColumn)\nFROM \(qualified);"
        default:
            sql = "SELECT \(quotedColumn)\nFROM \(qualified)\nLIMIT 200;"
        }
        appModel.openQueryTab(for: session, presetQuery: sql)
    }

    private func qualifiedTableName(schema: String, table: String, databaseType: DatabaseType) -> String {
        let tablePart = quoteIdentifier(table, databaseType: databaseType)
        let normalizedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedSchema.isEmpty || databaseType == .sqlite {
            return tablePart
        }
        let schemaPart = quoteIdentifier(normalizedSchema, databaseType: databaseType)
        return "\(schemaPart).\(tablePart)"
    }

    private func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        switch databaseType {
        case .mysql:
            let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        default:
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
    }

    private func focusExplorer(
        on session: ConnectionSession,
        database: String,
        schema: String,
        objectName: String,
        columnName: String?,
        objectType: SchemaObjectInfo.ObjectType = .table
    ) {
        let focus = ExplorerFocus(
            connectionID: session.connection.id,
            databaseName: database,
            schemaName: schema,
            objectName: objectName,
            objectType: objectType,
            columnName: columnName
        )
        navigationStore.focusExplorer(focus)
    }

    private func openDefinition(for objectName: String, schema: String, type: SchemaObjectInfo.ObjectType, in session: ConnectionSession) {
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: objectName,
                    schemaName: schema,
                    objectType: type
                )
                await MainActor.run {
                    appModel.openQueryTab(for: session, presetQuery: definition)
                }
            } catch {
                await MainActor.run {
                    appModel.lastError = DatabaseError.from(error)
                }
            }
        }
    }
}

private enum SearchSidebarConstants {
    static let scrollSpace = "SearchSidebarScrollSpace"
}
