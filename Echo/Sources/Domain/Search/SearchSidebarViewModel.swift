import Foundation
import Combine

@MainActor
final class SearchSidebarViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { scheduleSearch() }
    }

    @Published var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected }) {
        didSet { scheduleSearch() }
    }

    @Published private(set) var results: [SearchSidebarResult] = []
    @Published private(set) var isSearching: Bool = false
    @Published private(set) var errorMessage: String?

    private var databaseSession: DatabaseSession?
    private var databaseType: DatabaseType?
    private(set) var activeDatabaseName: String?
    private var searchTask: Task<Void, Never>?
    private let minimumQueryLength = 2
    private var isRestoring = false
    private var lastContextSession: ObjectIdentifier?
    private var lastContextDatabaseName: String?
    private var lastContextDatabaseType: DatabaseType?
    private var queryTabProvider: () -> [SearchSidebarQueryTabSnapshot] = { [] }

    var minimumSearchLength: Int { minimumQueryLength }

    var hasSelectedCategories: Bool {
        !selectedCategories.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateContext(databaseSession: DatabaseSession?, databaseName: String?, databaseType: DatabaseType?) {
        let normalizedName = databaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionIdentifier = databaseSession.map { ObjectIdentifier($0 as AnyObject) }
        let contextType = databaseType
        let isSameContext = sessionIdentifier == lastContextSession
            && normalizedName == lastContextDatabaseName
            && contextType == lastContextDatabaseType

        databaseSessionUpdated(databaseSession)
        self.databaseType = databaseType
        activeDatabaseName = normalizedName

        lastContextSession = sessionIdentifier
        lastContextDatabaseName = normalizedName
        lastContextDatabaseType = contextType

        if databaseSession == nil {
            if selectedCategories.contains(.queryTabs) {
                scheduleSearch()
            } else {
                cancelSearch()
                results = []
                isSearching = false
                errorMessage = nil
            }
            return
        }

        if isSameContext {
            return
        }

        scheduleSearch()
    }

    func resetFilters() {
        selectedCategories = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected })
    }

    func toggleCategory(_ category: SearchSidebarCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func clearQuery() {
        query = ""
    }

    func retryLastSearch() {
        scheduleSearch()
    }

    func restore(from cache: SearchSidebarCache) {
        isRestoring = true
        searchTask?.cancel()
        query = cache.query
        selectedCategories = cache.selectedCategories
        results = cache.results
        isSearching = cache.isSearching
        errorMessage = cache.errorMessage
        isRestoring = false
    }

    func snapshot() -> SearchSidebarCache {
        SearchSidebarCache(
            query: query,
            selectedCategories: selectedCategories,
            results: results,
            errorMessage: errorMessage,
            isSearching: isSearching
        )
    }

    func setQueryTabProvider(_ provider: @escaping () -> [SearchSidebarQueryTabSnapshot]) {
        queryTabProvider = provider
    }

    func notifyQueryTabsChanged() {
        guard !isRestoring else { return }
        if !trimmedQuery.isEmpty, trimmedQuery.count >= minimumQueryLength, hasSelectedCategories {
            scheduleSearch()
        }
    }

    var isRestoringState: Bool { isRestoring }

    private func databaseSessionUpdated(_ session: DatabaseSession?) {
        databaseSession = session
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard !isRestoring else { return }
        let searchText = trimmedQuery
        errorMessage = nil

        guard !searchText.isEmpty else {
            results = []
            isSearching = false
            searchTask = nil
            return
        }

        guard searchText.count >= minimumQueryLength else {
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
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
                try Task.checkCancellation()

                var aggregated: [SearchSidebarResult] = []
                var dbErrorDescription: String?

                if shouldSearchDatabase, let session {
                    let service = DatabaseSearchService(
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
                await MainActor.run {
                    guard let self else { return }
                    self.searchTask = nil
                }
            } catch {
                let dbError = DatabaseError.from(error)
                await MainActor.run {
                    guard let self else { return }
                    let tabResults = self.searchQueryTabs(with: searchText, snapshots: tabSnapshots, includeQueryTabs: shouldSearchQueryTabs)
                    self.results = self.sortResults(tabResults)
                    self.isSearching = false
                    self.errorMessage = dbError.errorDescription ?? error.localizedDescription
                    self.searchTask = nil
                }
            }
        }
    }

    private func searchQueryTabs(
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
                    return DatabaseSearchService.makeSnippet(from: snapshot.sql, matching: trimmed, radius: 100)
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

    private func fallbackSnippet(
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

    private func sortResults(_ results: [SearchSidebarResult]) -> [SearchSidebarResult] {
        results.sorted { lhs, rhs in
            if lhs.category == rhs.category {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.category.displayName.localizedCaseInsensitiveCompare(rhs.category.displayName) == .orderedAscending
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
