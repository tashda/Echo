import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("Query library · round 39")
struct QueryLibraryTests {
    private func state() -> AppState { AppState(historyDefaults: UserDefaults(suiteName: "QueryLibrary.\(UUID())")!) }

    @Test func defaultLimitAndCountPruning() {
        let app = state()
        #expect(app.queryHistoryLimit == 5_000)
        let now = Date()
        app.queryHistory = (0..<5_003).map { QueryHistoryItem(query: "SELECT \($0)", timestamp: now.addingTimeInterval(-Double($0))) }
        app.pruneQueryHistory(now: now)
        #expect(app.queryHistory.count == 5_000)
        #expect(app.queryHistory.last?.query == "SELECT 4999")
        app.queryHistoryLimit = 500
        #expect(app.queryHistory.count == 500)
    }

    @Test func retentionExpiresOldSQLAndNeverDisablesCapture() {
        let app = state()
        app.queryHistoryRetentionHours = 1
        let now = Date()
        app.queryHistory = [QueryHistoryItem(query: "recent", timestamp: now), QueryHistoryItem(query: "expired", timestamp: now.addingTimeInterval(-3_601))]
        app.pruneQueryHistory(now: now)
        #expect(app.queryHistory.map(\.query) == ["recent"])
        app.queryHistoryRetentionHours = 0
        app.addToQueryHistory("SELECT secret")
        #expect(app.queryHistory.isEmpty)
        #expect(app.historyDefaults.data(forKey: "queryHistory") == Data("[]".utf8))
    }

    @Test func connectionOptOutCoversEveryOutcome() {
        let app = state()
        for outcome in [nil, "Failed", "Cancelled"] as [String?] {
            app.addToQueryHistory("SELECT secret", outcome: outcome, keepsHistory: false)
        }
        #expect(app.queryHistory.isEmpty)
        app.addToQueryHistory("SELECT 1", outcome: "Failed", connectionName: "Production")
        #expect(app.queryHistory.first?.outcome == "Failed")
        #expect(app.queryHistory.first?.connectionName == "Production")
    }

    @Test func clearCancelsPendingPersistence() async throws {
        let app = state()
        app.addToQueryHistory("SELECT secret")
        app.clearQueryHistory()
        try await Task.sleep(for: .milliseconds(700))
        let reloaded = AppState(historyDefaults: app.historyDefaults)
        #expect(reloaded.queryHistory.isEmpty)
    }

    @Test func legacyHistoryDecodesWithoutNewFields() throws {
        let old = QueryHistoryItem(query: "SELECT 1", timestamp: Date(), resultCount: 1)
        let data = try JSONEncoder().encode(old)
        let decoded = try JSONDecoder().decode(QueryHistoryItem.self, from: data)
        #expect(decoded.query == "SELECT 1")
        #expect(decoded.outcome == nil)
        #expect(decoded.connectionName == nil)
    }

    @Test func connectionPrivacyPersistsAndOldConnectionsDefaultToRecording() throws {
        var connection = SavedConnection(connectionName: "Test", host: "localhost", port: 5432, database: "test", username: "test")
        connection.keepsQueryHistory = false
        let data = try JSONEncoder().encode(connection)
        #expect(try JSONDecoder().decode(SavedConnection.self, from: data).keepsQueryHistory == false)
        var old = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        old.removeValue(forKey: "keepsQueryHistory")
        let oldData = try JSONSerialization.data(withJSONObject: old)
        #expect(try JSONDecoder().decode(SavedConnection.self, from: oldData).keepsQueryHistory)
    }

    @Test func inspectorContentIsExclusiveAndTreeStaysHidden() {
        let app = state()
        app.isWorkspaceTreeVisible = false
        app.showInfoSidebar = true
        app.showWorkspaceLibrary(.history)
        #expect(app.isInspectorColumnVisible)
        #expect(!app.showInfoSidebar)
        #expect(!app.isWorkspaceTreeVisible)
        app.showNotificationHistory()
        #expect(app.workspaceLibrary == nil)
        app.showWorkspaceLibrary(.bookmarks)
        #expect(!app.isNotificationHistoryVisible)
        app.toggleInspector()
        #expect(app.workspaceLibrary == nil)
        #expect(app.showInfoSidebar)
        app.toggleInspector()
        #expect(!app.isInspectorColumnVisible)
    }

    @Test func retiredClipboardCannotCaptureOrImport() {
        let clipboard = ClipboardHistoryStore()
        clipboard.setEnabled(true)
        clipboard.record(.queryEditor, content: "SELECT secret")
        clipboard.importEntries([.init(source: .queryEditor, content: "legacy")])
        #expect(!clipboard.isEnabled)
        #expect(clipboard.entries.isEmpty)
        #expect(clipboard.usage.totalBytes == 0)
    }
}
