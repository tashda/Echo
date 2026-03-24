import SwiftUI

extension SearchSidebarView {

    @ViewBuilder
    var content: some View {
        if !viewModel.hasSessions {
            SearchPlaceholderView(
                systemImage: "externaldrive",
                title: "No connections",
                subtitle: "Connect to a database server to start searching."
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
                title: "Search across all connections",
                subtitle: "Enter at least \(viewModel.minimumSearchLength) characters to see results."
            )
        } else if viewModel.isSearching && viewModel.results.isEmpty {
            VStack(spacing: SpacingTokens.sm) {
                ProgressView()
                Text("Searching...")
                    .font(TypographyTokens.caption2.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        } else if let error = viewModel.errorMessage, viewModel.results.isEmpty {
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

    var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.sm, pinnedViews: .sectionHeaders) {
                ForEach(groupedResults, id: \.key) { group in
                    Section {
                        VStack(spacing: SpacingTokens.xs) {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: resultToLegacy(result),
                                    query: viewModel.trimmedQuery,
                                    onSelect: { handleResultTap(result) },
                                    fetchDefinition: definitionFetcher(for: result)
                                )
                            }
                        }
                        .padding(.horizontal, SpacingTokens.xxxs)
                        .padding(.bottom, SpacingTokens.xxs)
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

    struct ResultGroup: Identifiable {
        let key: String
        let displayTitle: String
        let results: [GlobalSearchResult]
        var id: String { key }
    }

    var groupedResults: [ResultGroup] {
        let multiServer = viewModel.sessions.count > 1

        if multiServer {
            // Group by Server > Category
            let grouped = Dictionary(grouping: viewModel.results) { result in
                "\(result.serverName)|\(result.category.rawValue)"
            }
            var groups: [ResultGroup] = []
            for (key, results) in grouped.sorted(by: { $0.key < $1.key }) {
                guard let first = results.first else { continue }
                let title = "\(first.serverName) — \(first.category.displayName)"
                groups.append(ResultGroup(key: key, displayTitle: title, results: results))
            }
            return groups
        } else {
            // Single server: group by category only
            let grouped = Dictionary(grouping: viewModel.results, by: \.category)
            return SearchSidebarCategory.allCases.compactMap { category in
                guard let results = grouped[category] else { return nil }
                return ResultGroup(key: category.rawValue, displayTitle: category.displayName, results: results)
            }
        }
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

    func definitionFetcher(for result: GlobalSearchResult) -> (() async throws -> String)? {
        guard let payload = result.payload else { return nil }
        guard let session = viewModel.session(for: result.connectionSessionID) else { return nil }

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
}
