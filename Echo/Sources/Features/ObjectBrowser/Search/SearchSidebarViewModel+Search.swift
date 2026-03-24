import Foundation

extension SearchSidebarViewModel {

    internal func performScheduleSearch() {
        searchTask?.cancel()
        guard !isRestoringState else { return }
        let searchText = trimmedQuery
        errorMessage = nil

        guard !searchText.isEmpty else {
            results = []
            isSearching = false
            searchTask = nil
            return
        }

        guard searchText.count >= minimumSearchLength else {
            results = []
            isSearching = false
            searchTask = nil
            return
        }

        guard hasSelectedCategories else {
            results = []
            isSearching = false
            searchTask = nil
            return
        }

        let categories = selectedCategories
        let metadataCategories = Set(categories.filter { $0 != .queryTabs })
        let shouldSearchQueryTabs = categories.contains(.queryTabs)
        let currentScope = scope
        let currentSessions = sessions
        let tabSnapshots = queryTabProvider()

        // Tier 1: In-memory metadata search (instant, no debounce)
        if !metadataCategories.isEmpty && !currentSessions.isEmpty {
            let metadataResults = MetadataSearchEngine.search(
                query: searchText,
                scope: currentScope,
                sessions: currentSessions,
                categories: metadataCategories
            )
            results = metadataResults
        } else {
            results = []
        }

        // Tier 1.5: Query tab search (needs debounce since it reads SQL content)
        if shouldSearchQueryTabs {
            isSearching = true
            searchTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms debounce
                guard !Task.isCancelled, let self else { return }

                let tabResults = self.searchQueryTabs(with: searchText, snapshots: tabSnapshots)

                await MainActor.run {
                    // Append tab results to existing metadata results
                    var combined = self.results.filter { $0.category != .queryTabs }
                    combined.append(contentsOf: tabResults)
                    self.results = combined
                    self.isSearching = false
                    self.searchTask = nil
                }
            }
        } else {
            isSearching = false
            searchTask = nil
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

            // Resolve server name from sessions
            let session = sessions.first { $0.id == snapshot.connectionSessionID }
            let serverName: String = {
                guard let session else { return "Unknown" }
                let name = session.connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
                return name.isEmpty ? session.connection.host : name
            }()
            let databaseType = session?.connection.databaseType ?? .postgresql

            let snippet: String? = {
                if let match = sqlMatchRange {
                    return ObjectSearchProvider.makeSnippet(from: snapshot.sql, matching: trimmed, radius: 100)
                        ?? fallbackSnippet(for: snapshot.sql, matching: trimmed, around: match)
                }
                if !snapshot.sql.isEmpty {
                    let candidate = snapshot.sql.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !candidate.isEmpty else { return nil }
                    let limit = 160
                    if candidate.count <= limit {
                        return candidate
                    }
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

    internal func fallbackSnippet(
        for sql: String,
        matching query: String,
        around range: Range<String.Index>
    ) -> String? {
        guard !sql.isEmpty else { return nil }
        let radius = 120
        let lowerBound = sql.index(range.lowerBound, offsetBy: -radius, limitedBy: sql.startIndex) ?? sql.startIndex
        let upperBound = sql.index(range.upperBound, offsetBy: radius, limitedBy: sql.endIndex) ?? sql.endIndex
        var snippet = String(sql[lowerBound..<upperBound])
        snippet = snippet.replacingOccurrences(of: "\n", with: " ")
        snippet = snippet.replacingOccurrences(of: "\r", with: " ")
        while snippet.contains("  ") {
            snippet = snippet.replacingOccurrences(of: "  ", with: " ")
        }
        snippet = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
        if lowerBound > sql.startIndex {
            snippet = "…" + snippet
        }
        if upperBound < sql.endIndex {
            snippet += "…"
        }
        return snippet
    }

    internal func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
