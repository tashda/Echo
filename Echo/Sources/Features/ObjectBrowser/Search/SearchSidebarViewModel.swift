import Foundation

@MainActor @Observable
final class SearchSidebarViewModel {
    var query: String = "" {
        didSet { performScheduleSearch() }
    }

    var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected }) {
        didSet { performScheduleSearch() }
    }

    var results: [SearchSidebarResult] = []
    var isSearching: Bool = false
    var errorMessage: String?

    internal var databaseSession: DatabaseSession?
    internal var databaseType: DatabaseType?
    var activeDatabaseName: String?
    @ObservationIgnored internal var searchTask: Task<Void, Never>?
    @ObservationIgnored private let minimumQueryLength = 2
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored private var lastContextSession: ObjectIdentifier?
    @ObservationIgnored private var lastContextDatabaseName: String?
    @ObservationIgnored private var lastContextDatabaseType: DatabaseType?
    @ObservationIgnored internal var queryTabProvider: () -> [SearchSidebarQueryTabSnapshot] = { [] }

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
                performScheduleSearch()
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

        performScheduleSearch()
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
        performScheduleSearch()
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
            performScheduleSearch()
        }
    }

    var isRestoringState: Bool { isRestoring }

    private func databaseSessionUpdated(_ session: DatabaseSession?) {
        databaseSession = session
    }
}
