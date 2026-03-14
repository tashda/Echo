import SwiftUI

extension SearchSidebarView {
    private var requiresDatabaseContext: Bool {
        viewModel.selectedCategories.contains { $0 != .queryTabs }
    }

    private var hasQueryTabFilter: Bool {
        viewModel.selectedCategories.contains(.queryTabs)
    }

    @ViewBuilder
    var content: some View {
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
            VStack(spacing: SpacingTokens.sm) {
                ProgressView()
                Text("Searching...")
                    .font(TypographyTokens.caption2.weight(.medium))
                    .foregroundStyle(ColorTokens.Text.secondary)
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

    var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SpacingTokens.sm, pinnedViews: .sectionHeaders) {
                ForEach(groupedResults, id: \.category) { group in
                    Section {
                        VStack(spacing: SpacingTokens.xs) {
                            ForEach(group.results) { result in
                                SearchResultRow(
                                    result: result,
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
            .padding(.vertical, SpacingTokens.xxs)
            .padding(.horizontal, SpacingTokens.xxs)
        }
        .coordinateSpace(name: SearchSidebarConstants.scrollSpace)
    }

    var groupedResults: [(category: SearchSidebarCategory, results: [SearchSidebarResult])]
    {
        let groups = Dictionary(grouping: viewModel.results, by: \.category)
        return SearchSidebarCategory.allCases.compactMap { category in
            guard let results = groups[category] else { return nil }
            return (category, results)
        }
    }

    func definitionFetcher(for result: SearchSidebarResult) -> (() async throws -> String)? {
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
}
