import Foundation

extension SearchSidebarViewModel {

    internal func performScheduleSearch() {
        searchTask?.cancel()
        guard !isRestoringState else { return }
        let searchText = trimmedQuery
        errorMessage = nil

        guard !searchText.isEmpty else {
            results = []
            groupedResultsCache = []
            isSearching = false
            searchTask = nil
            return
        }

        guard searchText.count >= minimumSearchLength else {
            results = []
            groupedResultsCache = []
            isSearching = false
            searchTask = nil
            return
        }

        guard hasSelectedCategories else {
            results = []
            groupedResultsCache = []
            isSearching = false
            searchTask = nil
            return
        }

        let categories = selectedCategories
        let metadataCategories = Set(categories.filter { $0 != .queryTabs })
        let shouldSearchQueryTabs = categories.contains(.queryTabs)
        let currentScope = scope
        let sessionCount = sessions.count
        let tabSnapshots = queryTabProvider()

        // Snapshot session data for Sendable boundary crossing
        let snapshots: [MetadataSearchEngine.SessionSnapshot] = sessions.compactMap { session in
            guard let structure = session.databaseStructure else { return nil }
            let serverName = session.connection.connectionName.isEmpty
                ? session.connection.host
                : session.connection.connectionName
            return MetadataSearchEngine.SessionSnapshot(
                sessionID: session.id,
                serverName: serverName,
                databaseType: session.connection.databaseType,
                structure: structure
            )
        }

        isSearching = true

        searchTask = Task {
            // 50ms debounce — prevents per-keystroke work
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            // Tier 1: metadata search (off MainActor via @concurrent async)
            var combined: [GlobalSearchResult] = []
            if !metadataCategories.isEmpty && !snapshots.isEmpty {
                let metadataResults = await MetadataSearchEngine.search(
                    query: searchText,
                    scope: currentScope,
                    snapshots: snapshots,
                    categories: metadataCategories
                )
                guard !Task.isCancelled else { return }
                combined = metadataResults
            }

            // Update results immediately with metadata hits
            self.results = combined
            self.groupedResultsCache = Self.groupResults(combined, sessionCount: sessionCount)

            // Tier 1.5: query tab search (additional 100ms debounce)
            if shouldSearchQueryTabs {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }

                let tabResults = searchQueryTabs(with: searchText, snapshots: tabSnapshots)
                if !tabResults.isEmpty {
                    combined.append(contentsOf: tabResults)
                    self.results = combined
                    self.groupedResultsCache = Self.groupResults(combined, sessionCount: sessionCount)
                }
            }

            self.isSearching = false
            self.searchTask = nil
        }
    }

    internal func searchQueryTabs(
        with query: String,
        snapshots: [SearchSidebarQueryTabSnapshot]
    ) -> [GlobalSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return snapshots.compactMap { snapshot in
            let titleMatch = snapshot.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            let sqlMatchRange = snapshot.sql.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive])
            guard titleMatch || sqlMatchRange != nil else { return nil }

            let session = sessions.first { $0.id == snapshot.connectionSessionID }
            let serverName: String = {
                guard let session else { return "Unknown" }
                let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? session.connection.host : name
            }()
            let databaseType = session?.connection.databaseType ?? .postgresql

            let snippet: String? = {
                if sqlMatchRange != nil {
                    return SearchSnippetGenerator.makeSnippet(from: snapshot.sql, matching: trimmed, radius: 100)
                }
                if !snapshot.sql.isEmpty {
                    let candidate = snapshot.sql.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !candidate.isEmpty else { return nil }
                    let limit = 160
                    if candidate.count <= limit { return candidate }
                    let index = candidate.index(candidate.startIndex, offsetBy: limit, limitedBy: candidate.endIndex) ?? candidate.endIndex
                    return String(candidate[..<index]) + "…"
                }
                return nil
            }()

            return GlobalSearchResult(
                connectionSessionID: snapshot.connectionSessionID,
                serverName: serverName,
                databaseName: snapshot.metadata ?? "",
                databaseType: databaseType,
                category: .queryTabs,
                title: snapshot.title,
                subtitle: snapshot.subtitle,
                metadata: snapshot.metadata,
                snippet: snippet,
                payload: .queryTab(tabID: snapshot.tabID, connectionSessionID: snapshot.connectionSessionID)
            )
        }
    }

    internal func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
