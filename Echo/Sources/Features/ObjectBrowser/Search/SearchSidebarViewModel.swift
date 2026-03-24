import Foundation

@MainActor @Observable
final class SearchSidebarViewModel {
    var query: String = "" {
        didSet { performScheduleSearch() }
    }

    var selectedCategories: Set<SearchSidebarCategory> = Set(SearchSidebarCategory.allCases.filter { $0.defaultSelected }) {
        didSet { performScheduleSearch() }
    }

    var scope: SearchScope = .allServers {
        didSet { performScheduleSearch() }
    }

    var results: [GlobalSearchResult] = []
    var isSearching: Bool = false
    var errorMessage: String?

    /// All active sessions — set by the view when context changes.
    internal var sessions: [ConnectionSession] = []

    @ObservationIgnored internal var searchTask: Task<Void, Never>?
    @ObservationIgnored private let minimumQueryLength = 2
    @ObservationIgnored private var isRestoring = false
    @ObservationIgnored internal var queryTabProvider: () -> [SearchSidebarQueryTabSnapshot] = { [] }

    var minimumSearchLength: Int { minimumQueryLength }

    var hasSelectedCategories: Bool {
        !selectedCategories.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasSessions: Bool {
        !sessions.isEmpty
    }

    /// Available servers for the scope picker.
    var availableServers: [(id: UUID, name: String)] {
        sessions.map { session in
            let name = session.connection.connectionName.isEmpty
                ? session.connection.host
                : session.connection.connectionName
            return (id: session.id, name: name)
        }
    }

    func updateSessions(_ newSessions: [ConnectionSession]) {
        let oldIDs = Set(sessions.map(\.id))
        let newIDs = Set(newSessions.map(\.id))
        sessions = newSessions

        // Validate scope — if the scoped server disconnected, reset to allServers
        switch scope {
        case .allServers:
            break
        case .server(let id):
            if !newIDs.contains(id) {
                scope = .allServers
            }
        case .database(let id, _):
            if !newIDs.contains(id) {
                scope = .allServers
            }
        }

        if oldIDs != newIDs {
            performScheduleSearch()
        }
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

    func restore(from cache: GlobalSearchSidebarCache) {
        isRestoring = true
        searchTask?.cancel()
        query = cache.query
        selectedCategories = cache.selectedCategories
        scope = cache.scope
        results = cache.results
        isSearching = cache.isSearching
        errorMessage = cache.errorMessage
        isRestoring = false
    }

    func snapshot() -> GlobalSearchSidebarCache {
        GlobalSearchSidebarCache(
            query: query,
            selectedCategories: selectedCategories,
            scope: scope,
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

    /// Resolves a session by ID from the current sessions list.
    func session(for connectionSessionID: UUID) -> ConnectionSession? {
        sessions.first { $0.id == connectionSessionID }
    }
}
