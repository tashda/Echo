import Foundation

extension AppState {
    /// History stores SQL and run metadata; result-cache expiry remains independent (round 39).
    var queryHistoryLimit: Int {
        get { max(1, historyDefaults.object(forKey: "queryHistoryLimit") as? Int ?? 5_000) }
        set { historyDefaults.set(max(1, newValue), forKey: "queryHistoryLimit"); pruneQueryHistory() }
    }
    var queryHistoryRetentionHours: Int {
        get { historyDefaults.object(forKey: "queryHistoryRetentionHours") as? Int ?? -1 }
        set { historyDefaults.set(newValue, forKey: "queryHistoryRetentionHours"); pruneQueryHistory() }
    }
    var queryHistoryBytes: Int { (try? JSONEncoder().encode(queryHistory).count) ?? 0 }

    func addToQueryHistory(_ query: String, connectionID: UUID? = nil, databaseName: String? = nil,
                          resultCount: Int? = nil, duration: TimeInterval? = nil,
                          outcome: String? = nil, connectionName: String? = nil, keepsHistory: Bool = true) {
        guard keepsHistory, queryHistoryRetentionHours != 0 else { return }
        var item = QueryHistoryItem(query: query, timestamp: Date(), connectionID: connectionID,
                                    databaseName: databaseName, resultCount: resultCount, duration: duration)
        item.outcome = outcome
        item.connectionName = connectionName
        queryHistory.insert(item, at: 0)
        pruneQueryHistory()
    }

    func clearQueryHistory() {
        historySaveTask?.cancel()
        queryHistory.removeAll()
        historyDefaults.set(Data("[]".utf8), forKey: "queryHistory")
    }

    func pruneQueryHistory(now: Date = Date()) {
        let hours = queryHistoryRetentionHours
        queryHistory = Array(queryHistory
            .filter { hours < 0 || (hours > 0 && $0.timestamp > now.addingTimeInterval(-Double(hours) * 3_600)) }
            .prefix(queryHistoryLimit))
        if hours == 0 { clearQueryHistory() } else { saveQueryHistory() }
    }

    func loadQueryHistory() {
        if let data = historyDefaults.data(forKey: "queryHistory"),
           let history = try? JSONDecoder().decode([QueryHistoryItem].self, from: data) {
            queryHistory = history.sorted { $0.timestamp > $1.timestamp }
        }
        pruneQueryHistory()
    }

    private func saveQueryHistory() {
        historySaveTask?.cancel()
        let history = queryHistory
        historySaveTask = Task(name: "Save query history") {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let data = await QueryHistoryEncoding.encode(history)
            guard !Task.isCancelled, let data else { return }
            historyDefaults.set(data, forKey: "queryHistory")
        }
    }

}

enum WorkspaceLibrarySection: String, CaseIterable {
    case bookmarks = "Bookmarks"
    case history = "History"
}

extension AppState {
    func showWorkspaceLibrary(_ section: WorkspaceLibrarySection) {
        showInfoSidebar = false
        isNotificationHistoryVisible = false
        workspaceLibrary = section
    }
}
