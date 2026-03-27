import SwiftUI

extension SearchSidebarView {

    /// Content uses a stable ZStack so the view tree structure never changes
    /// when switching between placeholder and results. This prevents structural
    /// identity changes that would propagate up and destroy @FocusState in the
    /// search bar (which lives in the parent's safeAreaInset).
    var content: some View {
        ZStack {
            if !viewModel.groupedResultsCache.isEmpty {
                resultsList
            }

            if let placeholder = placeholderContent {
                placeholder
            }
        }
    }

    @ViewBuilder
    private var placeholderContent: (some View)? {
        if !viewModel.hasSessions {
            ContentUnavailableView(
                "No Connections",
                systemImage: "externaldrive",
                description: Text("Connect to a database server to start searching.")
            )
        } else if viewModel.selectedCategories.isEmpty {
            ContentUnavailableView(
                "No Filters Selected",
                systemImage: "slider.horizontal.3",
                description: Text("Pick one or more object types to include in the search.")
            )
        } else if viewModel.trimmedQuery.count < viewModel.minimumSearchLength {
            ContentUnavailableView(
                "Search",
                systemImage: "magnifyingglass",
                description: Text("Enter at least \(viewModel.minimumSearchLength) characters to see results.")
            )
        } else if viewModel.isSearching && viewModel.groupedResultsCache.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, SpacingTokens.xl)
        } else if let error = viewModel.errorMessage, viewModel.groupedResultsCache.isEmpty {
            ContentUnavailableView {
                Label("Search Failed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error)
            } actions: {
                Button("Try Again") { viewModel.retryLastSearch() }
            }
        } else if viewModel.groupedResultsCache.isEmpty && viewModel.trimmedQuery.count >= viewModel.minimumSearchLength && !viewModel.isSearching {
            ContentUnavailableView.search(text: viewModel.trimmedQuery)
        }
    }

    var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.xs, pinnedViews: .sectionHeaders) {
                ForEach(viewModel.groupedResultsCache, id: \.key) { group in
                    Section {
                        VStack(spacing: 0) {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: resultToLegacy(result),
                                    query: viewModel.trimmedQuery,
                                    serverName: result.serverName,
                                    databaseName: result.databaseName,
                                    onSelect: { handleResultTap(result) },
                                    fetchDefinition: definitionFetcher(for: result),
                                    onOpenDefinitionInEditor: openInEditorAction(for: result)
                                )
                                .contextMenu { searchResultContextMenu(for: result) }
                            }
                        }
                        .padding(.bottom, SpacingTokens.xxs2)
                    } header: {
                        SidebarStickySectionHeader(
                            title: group.displayTitle,
                            count: group.results.count,
                            isExpanded: true,
                            coordinateSpaceName: SearchSidebarConstants.scrollSpace,
                            onTap: nil
                        )
                    }
                    .id("search-section-\(group.key)")
                }
            }
            .padding(.vertical, SpacingTokens.xxs)
            .padding(.horizontal, SpacingTokens.xxs)
        }
        .coordinateSpace(name: SearchSidebarConstants.scrollSpace)
    }


    /// Bridge a GlobalSearchResult to SearchSidebarResult for the existing SearchResultRow view.
    func resultToLegacy(_ result: GlobalSearchResult) -> SearchSidebarResult {
        SearchSidebarResult(
            category: result.category,
            title: result.title,
            subtitle: result.subtitle,
            metadata: result.metadata,
            snippet: result.snippet,
            payload: result.payload
        )
    }

    func openInEditorAction(for result: GlobalSearchResult) -> ((String) -> Void)? {
        guard let session = viewModel.session(for: result.connectionSessionID) else { return nil }
        guard definitionFetcher(for: result) != nil else { return nil }
        return { definition in
            environmentState.openQueryTab(for: session, presetQuery: definition, database: result.databaseName)
        }
    }

    func definitionFetcher(for result: GlobalSearchResult) -> (() async throws -> String)? {
        guard let payload = result.payload else { return nil }
        guard let session = viewModel.session(for: result.connectionSessionID) else { return nil }
        let database = result.databaseName

        switch payload {
        case .schemaObject(let schema, let name, let type):
            switch type {
            case .view, .materializedView, .function, .procedure, .trigger:
                return {
                    try await session.session.getObjectDefinition(
                        objectName: name,
                        schemaName: schema,
                        objectType: type,
                        database: database
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
                    objectType: .function,
                    database: database
                )
            }
        case .procedure(let schema, let name):
            return {
                try await session.session.getObjectDefinition(
                    objectName: name,
                    schemaName: schema,
                    objectType: .procedure,
                    database: database
                )
            }
        case .trigger(let schema, _, let name):
            return {
                try await session.session.getObjectDefinition(
                    objectName: name,
                    schemaName: schema,
                    objectType: .trigger,
                    database: database
                )
            }
        default:
            return nil
        }
    }
}
