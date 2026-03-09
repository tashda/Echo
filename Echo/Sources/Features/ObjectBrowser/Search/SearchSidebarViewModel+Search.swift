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
        let databaseCategories = Set(categories.filter { $0 != .queryTabs })
        let shouldSearchDatabase = databaseSession != nil && !databaseCategories.isEmpty
        let shouldSearchQueryTabs = categories.contains(.queryTabs)

        if !shouldSearchDatabase && !shouldSearchQueryTabs {
            results = []
            isSearching = false
            searchTask = nil
            return
        }

        let session = databaseSession
        let selectedType = databaseType ?? .postgresql
        let selectedDatabase = activeDatabaseName
        let tabSnapshots = queryTabProvider()

        isSearching = true

        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
                try Task.checkCancellation()

                guard let self else { return }
                var aggregated: [SearchSidebarResult] = []
                var dbErrorDescription: String?

                if shouldSearchDatabase, let session {
                    let service = ObjectSearchProvider(
                        session: session,
                        databaseType: selectedType,
                        activeDatabase: selectedDatabase
                    )
                    do {
                        let fetched = try await service.search(query: searchText, categories: databaseCategories)
                        aggregated.append(contentsOf: fetched)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        dbErrorDescription = DatabaseError.from(error).errorDescription ?? error.localizedDescription
                    }
                }

                let tabResults = self.searchQueryTabs(with: searchText, snapshots: tabSnapshots, includeQueryTabs: shouldSearchQueryTabs)
                aggregated.append(contentsOf: tabResults)

                let sorted = self.sortResults(aggregated)

                await MainActor.run {
                    self.results = sorted
                    self.isSearching = false
                    self.errorMessage = dbErrorDescription
                    self.searchTask = nil
                }
            } catch is CancellationError {
                guard let self else { return }
                await MainActor.run {
                    self.searchTask = nil
                }
            } catch {
                let dbError = DatabaseError.from(error)
                guard let self else { return }
                await MainActor.run {
                    let tabResults = self.searchQueryTabs(with: searchText, snapshots: tabSnapshots, includeQueryTabs: shouldSearchQueryTabs)
                    self.results = self.sortResults(tabResults)
                    self.isSearching = false
                    self.errorMessage = dbError.errorDescription ?? error.localizedDescription
                    self.searchTask = nil
                }
            }
        }
    }

    internal func searchQueryTabs(
        with query: String,
        snapshots: [SearchSidebarQueryTabSnapshot],
        includeQueryTabs: Bool
    ) -> [SearchSidebarResult] {
        guard includeQueryTabs else { return [] }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return snapshots.compactMap { snapshot in
            let titleMatch = snapshot.title.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            let sqlMatchRange = snapshot.sql.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive])
            guard titleMatch || sqlMatchRange != nil else { return nil }

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

            return SearchSidebarResult(
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

    internal func sortResults(_ results: [SearchSidebarResult]) -> [SearchSidebarResult] {
        results.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.category.displayName.localizedCaseInsensitiveCompare(rhs.category.displayName) == .orderedAscending
        }
    }

    internal func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
