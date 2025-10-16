import SwiftUI
import Combine

struct SearchSidebarView: View {
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
        .onChange(of: appModel.selectedConnectionID) { _, _ in syncContext() }
        .onChange(of: activeSession?.id) { _, _ in syncContext() }
        .onChange(of: activeSession?.selectedDatabaseName) { _, _ in syncContext() }
        .onReceive(viewModel.$query.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$selectedCategories.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$results) { _ in cacheState() }
        .onReceive(viewModel.$errorMessage.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$isSearching.removeDuplicates()) { _ in cacheState() }
        .onChange(of: appModel.tabManager.tabs.map(\.id)) { _, _ in
            viewModel.notifyQueryTabsChanged()
        }
        .onChange(of: appModel.tabManager.activeTabId) { _, _ in
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
            FilterPopoverView(
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
            PlaceholderView(
                systemImage: "externaldrive",
                title: "No active connection",
                subtitle: "Connect to a database server to start searching."
            )
        } else if requiresDatabase && !hasQueryTabs && activeSession?.selectedDatabaseName?.isEmpty != false {
            PlaceholderView(
                systemImage: "cylinder",
                title: "Select a database",
                subtitle: "Choose a database for the current connection to search its objects."
            )
        } else if viewModel.selectedCategories.isEmpty {
            PlaceholderView(
                systemImage: "slider.horizontal.3",
                title: "Enable at least one filter",
                subtitle: "Pick one or more object types to include in the search."
            )
        } else if viewModel.trimmedQuery.count < viewModel.minimumSearchLength {
            PlaceholderView(
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
            PlaceholderView(
                systemImage: "exclamationmark.triangle",
                title: "Search failed",
                subtitle: error,
                actionTitle: "Try Again",
                action: { viewModel.retryLastSearch() }
            )
        } else if viewModel.results.isEmpty {
            PlaceholderView(
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
            case .view, .materializedView, .function, .trigger:
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
        if let selectedID = appModel.selectedConnectionID,
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
            case .view, .materializedView, .function, .trigger:
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

        case .trigger(let schema, _, let name):
            openDefinition(for: name, schema: schema, type: .trigger, in: session)

        case .queryTab(let tabID, let connectionSessionID):
            appModel.sessionManager.setActiveSession(connectionSessionID)
            appModel.tabManager.setActiveTab(tabID)
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
        appModel.pendingExplorerFocus = focus
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

private struct SearchResultRow: View {
    let result: SearchSidebarResult
    let query: String
    let onSelect: () -> Void
    let fetchDefinition: (() async throws -> String)?

    @State private var isHovered = false
    @State private var isInfoPresented = false
    @State private var infoState: InfoState = .idle

    var body: some View {
        rowContent
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture(perform: onSelect)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
#if os(macOS)
            .onHover { hovering in
                isHovered = hovering
            }
#endif
            .onChange(of: isInfoPresented) { _, newValue in
                if !newValue {
                    infoState = .idle
                }
            }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: result.category.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let subtitle = result.subtitle, !subtitle.isEmpty {
                            if shouldShowBadge {
                                Text(subtitle)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.primary.opacity(0.08), in: Capsule())
                            } else {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if let metadata = result.metadata,
                           !metadata.isEmpty {
                            let tint: Color = (result.category == .columns) ? .accentColor : .secondary
                            Text(metadata)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(tint.opacity(0.08), in: Capsule())
                        }

                        if let fetchDefinition {
                            infoButton(fetch: fetchDefinition)
                        }
                    }
                }

                if let snippet = result.snippet, !snippet.isEmpty {
                    snippetText(for: truncatedSnippet(snippet))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .overlay(cardBorder)
        .shadow(color: isHovered ? Color.black.opacity(0.12) : .clear, radius: isHovered ? 14 : 0, y: isHovered ? 8 : 0)
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }

    private func snippetText(for snippet: String) -> Text {
        guard shouldHighlightSnippet, !query.isEmpty else {
            return Text(snippet)
        }

        var attributed = AttributedString()
        var currentIndex = snippet.startIndex
        let endIndex = snippet.endIndex
        var searchRange = currentIndex..<endIndex

        while let matchRange = snippet.range(of: query, options: [.caseInsensitive], range: searchRange) {
            if matchRange.lowerBound > currentIndex {
                let prefix = String(snippet[currentIndex..<matchRange.lowerBound])
                if !prefix.isEmpty {
                    attributed.append(AttributedString(prefix))
                }
            }

            let matchText = String(snippet[matchRange])
            var matchAttributed = AttributedString(matchText)
            matchAttributed.font = .system(size: 11, weight: .semibold)
            attributed.append(matchAttributed)

            currentIndex = matchRange.upperBound
            searchRange = currentIndex..<endIndex
        }

        if currentIndex < endIndex {
            let suffix = String(snippet[currentIndex..<endIndex])
            if !suffix.isEmpty {
                attributed.append(AttributedString(suffix))
            }
        }

        if attributed.characters.isEmpty {
            return Text(snippet)
        }

        return Text(attributed)
    }

    private func truncatedSnippet(_ snippet: String) -> String {
        guard shouldHighlightSnippet else { return snippet }
        let limit = 140
        guard snippet.count > limit else { return snippet }
        let endIndex = snippet.index(snippet.startIndex, offsetBy: limit, limitedBy: snippet.endIndex) ?? snippet.endIndex
        var truncated = String(snippet[..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        if truncated.isEmpty {
            truncated = String(snippet.prefix(limit))
        }
        return truncated.hasSuffix("…") ? truncated : truncated + "…"
    }

    private func infoButton(fetch: @escaping () async throws -> String) -> some View {
        Button {
            if isInfoPresented {
                isInfoPresented = false
                infoState = .idle
            } else {
                infoState = .loading
                isInfoPresented = true
            }
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isInfoPresented ? Color.accentColor : Color.secondary)
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.primary.opacity(isInfoPresented ? 0.12 : 0.04))
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isInfoPresented, arrowEdge: .trailing) {
            infoPopover(fetch: fetch)
                .frame(minWidth: 420, idealWidth: 480, maxWidth: 520)
                .padding(20)
        }
    }

    private func infoPopover(fetch: @escaping () async throws -> String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(result.title)
                .font(.headline)

            switch infoState {
            case .idle, .loading:
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading definition…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .task {
                    await loadDefinition(fetch: fetch)
                }
            case .failed(let message):
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            case .loaded(let definition):
                ScrollView {
                    Text(definition)
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 400)
            }

        }
    }

    private func loadDefinition(fetch: @escaping () async throws -> String) async {
        guard case .loading = infoState else { return }
        do {
            let definition = try await fetch()
            infoState = .loaded(definition)
        } catch {
            infoState = .failed(error.localizedDescription)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(isHovered ? 0.08 : 0.04))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(isHovered ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.05), lineWidth: 1)
    }

    private var shouldHighlightSnippet: Bool {
        switch result.category {
        case .views, .materializedViews, .functions, .triggers, .queryTabs:
            return true
        default:
            return false
        }
    }

    private var shouldShowBadge: Bool {
        switch result.category {
        case .tables, .views, .materializedViews, .columns, .indexes, .foreignKeys:
            return true
        default:
            return false
        }
    }

    private enum InfoState: Equatable {
        case idle
        case loading
        case loaded(String)
        case failed(String)
    }
}

private struct PlaceholderView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private enum SearchSidebarConstants {
    static let scrollSpace = "SearchSidebarScrollSpace"
}

private struct FilterPopoverView: View {
    @Binding var selectedCategories: Set<SearchSidebarCategory>
    let onSelectAll: () -> Void
    let onClearAll: () -> Void

    private func binding(for category: SearchSidebarCategory) -> Binding<Bool> {
        Binding(
            get: { selectedCategories.contains(category) },
            set: { newValue in
                if newValue {
                    selectedCategories.insert(category)
                } else {
                    selectedCategories.remove(category)
                }
            }
        )
    }

    private var sortedCategories: [SearchSidebarCategory] {
        SearchSidebarCategory.allCases
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filters")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button {
                    onSelectAll()
                } label: {
                    Text("Select All")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                Divider()
                    .frame(height: 14)
                Button {
                    onClearAll()
                } label: {
                    Text("Clear All")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(sortedCategories) { category in
#if os(macOS)
                    Toggle(category.displayName, isOn: binding(for: category))
                        .toggleStyle(.checkbox)
                        .font(.system(size: 11))
#else
                    Toggle(category.displayName, isOn: binding(for: category))
                        .font(.system(size: 11))
#endif
                }
            }
        }
    }
}

private func queryTabSnapshots(from appModel: AppModel?) -> [SearchSidebarQueryTabSnapshot] {
    guard let appModel else { return [] }
    let sessionsByID = Dictionary(uniqueKeysWithValues: appModel.sessionManager.sessions.map { ($0.id, $0) })

    var snapshots: [SearchSidebarQueryTabSnapshot] = []

    for tab in appModel.tabManager.tabs {
        guard let queryState = tab.query else { continue }
        let session = sessionsByID[tab.connectionSessionID]
        let connection = tab.connection
        let trimmedSelectedDatabase = session?.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let databaseName = (trimmedSelectedDatabase?.isEmpty == false ? trimmedSelectedDatabase : nil)
            ?? connection.database.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let serverText = connectionSummary(for: connection)
        var subtitleComponents: [String] = []
        if !serverText.isEmpty {
            subtitleComponents.append(serverText)
        }
        if let databaseName {
            subtitleComponents.append(databaseName)
        }
        let subtitle = subtitleComponents.isEmpty ? nil : subtitleComponents.joined(separator: " • ")

        snapshots.append(
            SearchSidebarQueryTabSnapshot(
                tabID: tab.id,
                connectionSessionID: tab.connectionSessionID,
                title: tab.title,
                subtitle: subtitle,
                metadata: nil,
                sql: queryState.sql
            )
        )
    }

    return snapshots
}

private func connectionSummary(for connection: SavedConnection) -> String {
    let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
    let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
    let user = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)

    var userHost: String?
    if !host.isEmpty {
        if !user.isEmpty {
            userHost = "\(user)@\(host)"
        } else {
            userHost = host
        }
    }

    if !name.isEmpty {
        if let userHost {
            return "\(name) (\(userHost))"
        }
        return name
    }

    return userHost ?? "Current Connection"
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
