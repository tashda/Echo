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

    var minimumSearchLength: Int { minimumQueryLength }

    var hasSelectedCategories: Bool {
        !selectedCategories.isEmpty
    }

    var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateContext(databaseSession: DatabaseSession?, databaseName: String?, databaseType: DatabaseType?) {
        databaseSessionUpdated(databaseSession)
        self.databaseType = databaseType
        activeDatabaseName = databaseName

        guard databaseSession != nil else {
            cancelSearch()
            results = []
            isSearching = false
            errorMessage = nil
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

    var isRestoringState: Bool { isRestoring }

    private func databaseSessionUpdated(_ session: DatabaseSession?) {
        databaseSession = session
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        guard let session = databaseSession else { return }
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

        isSearching = true

        let categories = selectedCategories
        searchTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 250_000_000) // 250ms debounce
                try Task.checkCancellation()

                let selectedType = self?.databaseType ?? .postgresql
                let selectedDatabase = self?.activeDatabaseName
                let service = DatabaseSearchService(
                    session: session,
                    databaseType: selectedType,
                    activeDatabase: selectedDatabase
                )
                let fetched = try await service.search(query: searchText, categories: categories)

                await MainActor.run {
                    guard let self else { return }
                    self.results = fetched
                    self.isSearching = false
                    self.errorMessage = nil
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
                    self.results = []
                    self.isSearching = false
                    self.errorMessage = dbError.errorDescription ?? error.localizedDescription
                    self.searchTask = nil
                }
            }
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
    }
}
