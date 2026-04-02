import Foundation
import SwiftUI

/// Centralized application state management

@Observable final class AppState: @unchecked Sendable {
    // MARK: - UI State
    var isLoading = false
    var currentError: DatabaseError?
    var showingError = false
    var activeSheet: ActiveSheet?
    var showTabOverview = false
    var showInfoSidebar = false
    var workspaceSidebarVisibility: NavigationSplitViewVisibility = .automatic
    var workspaceSidebarWidth: CGFloat = 320
    var workspaceTabBarStyle: WorkspaceTabBarStyle = .floating

    // MARK: - Query State
    var isQueryRunning = false
    var queryHistory: [QueryHistoryItem] = []
    var currentQuery = "SELECT NOW();"
    var sqlEditorTheme = SQLEditorTheme.fallback()
    var sqlEditorDisplay = SQLEditorDisplayOptions()

    // MARK: - Connection State
    var isConnecting = false
    var lastConnectionAttempt: Date?

    @ObservationIgnored private var errorDismissTask: Task<Void, Never>?

    init() {
        loadQueryHistory()
    }

    // MARK: - Error Management

    func showError(_ error: DatabaseError) {
        currentError = error
        showingError = true
        isLoading = false
        isConnecting = false
        isQueryRunning = false
        scheduleErrorDismiss()
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

    func addToQueryHistory(_ query: String, connectionID: UUID? = nil, databaseName: String? = nil, resultCount: Int? = nil, duration: TimeInterval? = nil) {
        let item = QueryHistoryItem(
            query: query,
            timestamp: Date(),
            connectionID: connectionID,
            databaseName: databaseName,
            resultCount: resultCount,
            duration: duration
        )
        queryHistory.insert(item, at: 0)

        // Keep only the last 500 queries
        if queryHistory.count > 500 {
            queryHistory = Array(queryHistory.prefix(500))
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

    private func scheduleErrorDismiss() {
        errorDismissTask?.cancel()
        errorDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            clearError()
        }
    }

    private func loadQueryHistory() {
        if let data = UserDefaults.standard.data(forKey: "queryHistory"),
        let history = try? JSONDecoder().decode([QueryHistoryItem] .self, from: data) {
            queryHistory = history
        }
    }

    private var historySaveTask: Task<Void, Never>?

    private func saveQueryHistory() {
        historySaveTask?.cancel()
        historySaveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let history = queryHistory
            let data = try? JSONEncoder().encode(history)
            if let data {
                UserDefaults.standard.set(data, forKey: "queryHistory")
            }
        }
    }
}

// MARK: - Supporting Types

enum ActiveSheet: String, Identifiable {
    case connectionEditor
    case quickConnect
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
    let connectionID: UUID?
    let databaseName: String?
    let resultCount: Int?
    let duration: TimeInterval?

    init(id: UUID = UUID(), query: String, timestamp: Date, connectionID: UUID? = nil, databaseName: String? = nil, resultCount: Int? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.query = query
        self.timestamp = timestamp
        self.connectionID = connectionID
        self.databaseName = databaseName
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
