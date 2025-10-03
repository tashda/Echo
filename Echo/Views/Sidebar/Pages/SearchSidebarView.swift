import SwiftUI
import Combine

struct SearchSidebarView: View {
    @EnvironmentObject private var appModel: AppModel
    @StateObject private var viewModel = SearchSidebarViewModel()
    @FocusState private var isSearchFieldFocused: Bool
    @State private var didRestoreCache = false
    @State private var isFilterPopoverPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            searchField
            Divider()
                .padding(.vertical, 4)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            restoreCacheIfNeeded()
            syncContext()
        }
        .onChange(of: appModel.selectedConnectionID) { _ in syncContext() }
        .onChange(of: activeSession?.id) { _ in syncContext() }
        .onChange(of: activeSession?.selectedDatabaseName ?? "") { _ in syncContext() }
        .onReceive(viewModel.$query.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$selectedCategories.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$results) { _ in cacheState() }
        .onReceive(viewModel.$errorMessage.removeDuplicates()) { _ in cacheState() }
        .onReceive(viewModel.$isSearching.removeDuplicates()) { _ in cacheState() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if let session = activeSession {
                serverLine(for: session)
            } else {
                Text("Connect to a database to enable search")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            filterButton
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tables, views, columns...", text: $viewModel.query)
                .textFieldStyle(.plain)
                .focused($isSearchFieldFocused)
                .disabled(activeSession?.selectedDatabaseName?.isEmpty != false)
            if !viewModel.query.isEmpty {
                Button {
                    viewModel.clearQuery()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var filterButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            Label(filterLabel, systemImage: "line.3.horizontal.decrease.circle")
                .labelStyle(.titleAndIcon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
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
    private func serverLine(for session: ConnectionSession) -> some View {
        let connection = session.connection
        let serverText = serverDescription(for: connection)
        let databaseName = session.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        HStack(spacing: 6) {
            Text(serverText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if databaseName.isEmpty {
                Text("· Select a database")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("· \(databaseName)")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func serverDescription(for connection: SavedConnection) -> String {
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

    @ViewBuilder
    private var content: some View {
        if activeSession == nil {
            PlaceholderView(
                systemImage: "externaldrive",
                title: "No active connection",
                subtitle: "Connect to a database server to start searching."
            )
        } else if activeSession?.selectedDatabaseName?.isEmpty != false {
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
                                    onSelect: { handleResultTap(result) }
                                )
                            }
                        }
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

    private var activeSession: ConnectionSession? {
        if let selectedID = appModel.selectedConnectionID,
           let session = appModel.sessionManager.sessionForConnection(selectedID) {
            return session
        }
        return appModel.sessionManager.activeSession
    }

    private func syncContext() {
        guard let session = activeSession else {
            viewModel.updateContext(databaseSession: nil, databaseName: nil, databaseType: nil)
            return
        }
        viewModel.updateContext(
            databaseSession: session.session,
            databaseName: session.selectedDatabaseName,
            databaseType: session.connection.databaseType
        )
    }

    private func restoreCacheIfNeeded() {
        guard !didRestoreCache else { return }
        viewModel.restore(from: appModel.searchSidebarCache)
        didRestoreCache = true
    }

    private func cacheState() {
        guard didRestoreCache, !viewModel.isRestoringState else { return }
        let snapshot = viewModel.snapshot()
        if snapshot != appModel.searchSidebarCache {
            appModel.searchSidebarCache = snapshot
        }
    }

    private func handleResultTap(_ result: SearchSidebarResult) {
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
                focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: .table)
            case .view, .materializedView:
                openDefinition(for: name, schema: schema, type: type, in: session)
            case .function:
                openDefinition(for: name, schema: schema, type: type, in: session)
            case .trigger:
                openDefinition(for: name, schema: schema, type: type, in: session)
            }

        case .column(let schema, let table, let column):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: table, columnName: column, objectType: .table)

        case .index(let schema, let table, _):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: table, columnName: nil, objectType: .table)

        case .foreignKey(let schema, let table, _):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: table, columnName: nil, objectType: .table)

        case .function(let schema, let name):
            openDefinition(for: name, schema: schema, type: .function, in: session)

        case .trigger(let schema, _, let name):
            openDefinition(for: name, schema: schema, type: .trigger, in: session)
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

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: result.category.systemImage)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 16)

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
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                            } else {
                                Text(subtitle)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer(minLength: 8)

                    if result.category == .columns,
                       let metadata = result.metadata,
                       !metadata.isEmpty {
                        Text(metadata)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.primary.opacity(0.05), in: Capsule())
                    }
                }

                if let snippet = result.snippet, !snippet.isEmpty {
                    snippetText(for: snippet)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func snippetText(for snippet: String) -> Text {
        guard shouldHighlightSnippet, !query.isEmpty else {
            return Text(snippet)
        }

        var pieces: [Text] = []
        var currentIndex = snippet.startIndex
        let endIndex = snippet.endIndex
        var searchRange = currentIndex..<endIndex

        while let matchRange = snippet.range(of: query, options: [.caseInsensitive], range: searchRange) {
            if matchRange.lowerBound > currentIndex {
                let prefix = String(snippet[currentIndex..<matchRange.lowerBound])
                if !prefix.isEmpty {
                    pieces.append(Text(prefix))
                }
            }

            let matchText = String(snippet[matchRange])
            pieces.append(Text(matchText).fontWeight(.bold))

            currentIndex = matchRange.upperBound
            searchRange = currentIndex..<endIndex
        }

        if currentIndex < endIndex {
            let suffix = String(snippet[currentIndex..<endIndex])
            if !suffix.isEmpty {
                pieces.append(Text(suffix))
            }
        }

        if pieces.isEmpty {
            return Text(snippet)
        }

        return pieces.dropFirst().reduce(pieces.first!) { result, next in
            result + next
        }
    }

    private var shouldHighlightSnippet: Bool {
        switch result.category {
        case .views, .materializedViews, .functions, .triggers:
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
