import EchoLocalStorage
import Foundation
import OSLog

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
    var queryHistoryBytes: Int { (try? LocalRecordEncoding.encode(queryHistory).count) ?? 0 }

    func addToQueryHistory(_ query: String, connectionID: UUID? = nil, databaseName: String? = nil,
                          resultCount: Int? = nil, duration: TimeInterval? = nil,
                          outcome: String? = nil, connectionName: String? = nil, errorMessage: String? = nil,
                          keepsHistory: Bool = true) {
        guard keepsHistory, queryHistoryRetentionHours != 0 else { return }
        var item = QueryHistoryItem(query: query, timestamp: Date(), connectionID: connectionID,
                                    databaseName: databaseName, resultCount: resultCount, duration: duration)
        item.outcome = outcome
        item.connectionName = connectionName
        item.errorMessage = errorMessage
        queryHistory.insert(item, at: 0)
        pruneQueryHistory()
    }

    /// Delete from History (round IC): removes these runs and saves.
    func removeFromQueryHistory(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        removedHistoryIDs.formUnion(ids)
        queryHistory.removeAll { ids.contains($0.id) }
        pruneQueryHistory()
    }

    func clearQueryHistory() {
        historySaveTask?.cancel()
        queryHistory.removeAll()
        historyWasCleared = true
        if historyDefaults !== UserDefaults.standard {
            historyDefaults.set(Data("[]".utf8), forKey: "queryHistory")
        } else { saveQueryHistory() }
    }

    func pruneQueryHistory(now: Date = Date()) {
        let hours = queryHistoryRetentionHours
        queryHistory = Array(queryHistory
            .filter { hours < 0 || (hours > 0 && $0.timestamp > now.addingTimeInterval(-Double(hours) * 3_600)) }
            .prefix(queryHistoryLimit))
        if hours == 0 { clearQueryHistory() } else { saveQueryHistory() }
    }

    func loadQueryHistory() {
        guard historyDefaults === UserDefaults.standard else {
            if let data = historyDefaults.data(forKey: "queryHistory"),
               let history = try? JSONDecoder().decode([QueryHistoryItem].self, from: data) {
                queryHistory = history.sorted { $0.timestamp > $1.timestamp }
            }
            pruneQueryHistory()
            return
        }
        historyLoadTask = Task(name: "Load encrypted query history") {
            do {
                let data = try await LocalArchive.shared.load(collection: "query-history",
                    legacyData: EncryptedRecordStore.isTestHost ? nil : historyDefaults.data(forKey: "queryHistory"))
                if let data, !historyWasCleared {
                    let stored = try JSONDecoder().decode([QueryHistoryItem].self, from: data)
                    let currentIDs = Set(queryHistory.map(\.id))
                    queryHistory += stored.filter { !currentIDs.contains($0.id) && !removedHistoryIDs.contains($0.id) }
                    queryHistory.sort { $0.timestamp > $1.timestamp }
                }
                if !EncryptedRecordStore.isTestHost { historyDefaults.removeObject(forKey: "queryHistory") }
                pruneQueryHistory()
            } catch {
                historyStorageAvailable = false
                Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Query history is unavailable: \(error.localizedDescription)")
            }
        }
    }

    private func saveQueryHistory() {
        historySaveTask?.cancel()
        historySaveTask = Task(name: "Save query history") {
            try? await Task.sleep(for: .milliseconds(300))
            await historyLoadTask?.value
            guard !Task.isCancelled, historyStorageAvailable else { return }
            let data = await QueryHistoryEncoding.encode(queryHistory)
            guard !Task.isCancelled, let data else { return }
            if historyDefaults === UserDefaults.standard {
                do { try await LocalArchive.shared.save(data, collection: "query-history") }
                catch {
                    Logger(subsystem: "dev.echodb.echo", category: "local-storage").error("Couldn't save query history: \(error.localizedDescription)")
                }
            } else { historyDefaults.set(data, forKey: "queryHistory") }
        }
    }
}
