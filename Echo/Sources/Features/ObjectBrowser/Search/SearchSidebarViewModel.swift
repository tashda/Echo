import Foundation
import Combine

@MainActor
final class SearchSidebarViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet { performScheduleSearch() }
    }

    @Published var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected }) {
        didSet { performScheduleSearch() }
    }

    @Published internal(set) var results: [SearchSidebarResult] = []
    @Published internal(set) var isSearching: Bool = false
    @Published internal(set) var errorMessage: String?

    internal var databaseSession: DatabaseSession?
    internal var databaseType: DatabaseType?
    internal(set) var activeDatabaseName: String?
    internal var searchTask: Task<Void, Never>?
    private let minimumQueryLength = 2
    private var isRestoring = false
    private var lastContextSession: ObjectIdentifier?
    private var lastContextDatabaseName: String?
    private var lastContextDatabaseType: DatabaseType?
    internal var queryTabProvider: () -> [SearchSidebarQueryTabSnapshot] = { [] }

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
