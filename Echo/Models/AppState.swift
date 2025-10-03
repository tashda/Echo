import Foundation
import SwiftUI
import Combine

/// Centralized application state management

@MainActor final class AppState: ObservableObject {
    // MARK: - UI State
    @Published var isLoading = false
    @Published var currentError: DatabaseError?
    @Published var showingError = false
    @Published var activeSheet: ActiveSheet?
    @Published var showTabOverview = false
    @Published var showInfoSidebar = false

    // MARK: - Query State
    @Published var isQueryRunning = false
    @Published var queryHistory: [QueryHistoryItem] = []
    @Published var currentQuery = "SELECT NOW();"
    @Published var sqlEditorTheme = SQLEditorTheme()
    @Published var sqlEditorDisplay = SQLEditorDisplayOptions()

    // MARK: - Connection State
    @Published var isConnecting = false
    @Published var lastConnectionAttempt: Date?

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupErrorHandling()
        loadQueryHistory()
    }

    // MARK: - Error Management

    func showError(_ error: DatabaseError) {
        currentError = error
        showingError = true
        isLoading = false
        isConnecting = false
        isQueryRunning = false
    }

    func clearError() {
        currentError = nil
        showingError = false
    }

    // MARK: - Loading States

    func startLoading() {
        isLoading = true
    }

    func stopLoading() {
        isLoading = false
    }

    // MARK: - Query Management

    func addToQueryHistory(_ query: String, resultCount: Int? = nil, duration: TimeInterval? = nil) {
        let item = QueryHistoryItem(
            query: query,
            timestamp: Date(),
            resultCount: resultCount,
            duration: duration
        )
        queryHistory.insert(item, at: 0)

        // Keep only the last 50 queries
        if queryHistory.count > 50 {
            queryHistory = Array(queryHistory.prefix(50))
        }

        saveQueryHistory()
    }

    func clearQueryHistory() {
        queryHistory.removeAll()
        saveQueryHistory()
    }

    // MARK: - Sheet Management

    func showSheet(_ sheet: ActiveSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    // MARK: - Private Methods

    private func setupErrorHandling() {
        // Auto-dismiss errors after 5 seconds
        $currentError.compactMap {
            $0
        }.debounce(for: .seconds(5), scheduler: RunLoop.main).sink {
            [weak self] _ in
            self?.clearError()
        }.store(in: &cancellables)
    }

    private func loadQueryHistory() {
        if let data = UserDefaults.standard.data(forKey: "queryHistory"),
        let history = try? JSONDecoder().decode([QueryHistoryItem] .self, from: data) {
            queryHistory = history
        }
    }

    private func saveQueryHistory() {
        if let data = try? JSONEncoder().encode(queryHistory) {
            UserDefaults.standard.set(data, forKey: "queryHistory")
        }
    }
}

// MARK: - Supporting Types

enum ActiveSheet: String, Identifiable {
    case connectionEditor
    case preferences
    case about
    case exportData

    var id: String {
        rawValue
    }
}

struct QueryHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String
    let timestamp: Date
    let resultCount: Int?
    let duration: TimeInterval?

    init(id: UUID = UUID(), query: String, timestamp: Date, resultCount: Int? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.resultCount = resultCount
        self.duration = duration
    }

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String? {
        guard let duration = duration else {
            return nil
        }
        return String(format: "%.3fs", duration)
    }
}
