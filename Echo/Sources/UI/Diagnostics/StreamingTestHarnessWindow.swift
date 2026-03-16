import Foundation
import SwiftUI

struct StreamingTestHarnessWindow: Scene {
    static let sceneID = "streaming-test-harness"

    var body: some Scene {
        Window("Streaming Test Harness", id: Self.sceneID) {
            StreamingTestHarnessView()
                .environment(AppDirector.shared.projectStore)
                .environment(AppDirector.shared.connectionStore)
                .environment(AppDirector.shared.navigationStore)
                .environment(AppDirector.shared.environmentState)
                .environment(AppDirector.shared.appearanceStore)
        }
        .defaultSize(width: 840, height: 620)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

struct StreamingTestHarnessView: View {
    @Environment(ProjectStore.self) internal var projectStore
    @Environment(ConnectionStore.self) internal var connectionStore
    @Environment(NavigationStore.self) internal var navigationStore
    
    @Environment(EnvironmentState.self) internal var environmentState
    @Environment(AppearanceStore.self) internal var appearanceStore
    @Bindable private var coordinator = AppDirector.shared

    @State internal var selectedSessionID: UUID?
    @State internal var sqlInput: String = "SELECT current_timestamp;"
    @State internal var isRunning = false
    @State internal var statusMessage: String?
    @State internal var errorMessage: String?
    @State internal var logs: [StreamingLogEntry] = []
    @State internal var report: QueryPerformanceTracker.Report?
    @State internal var runTask: Task<Void, Never>?
    @State internal var tracker: QueryPerformanceTracker = QueryPerformanceTracker(initialBatchTarget: 512)
    @State internal var logFilter: LogVisibility = .simple
    @State internal var pendingDebugLogs: [StreamingLogEntry] = []
    @State internal var debugFlushTask: Task<Void, Never>?
    @State internal var debugAggregator = DebugLogAggregator()

    internal var availableSessions: [ConnectionSession] {
        guard coordinator.isInitialized else { return [] }
        return environmentState.sessionGroup.sortedSessions
    }

    internal var selectedSession: ConnectionSession? {
        guard let id = selectedSessionID else { return availableSessions.first }
        return availableSessions.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Background.primary)
        .onAppear {
            if selectedSessionID == nil {
                selectedSessionID = availableSessions.first?.id
            }
        }
        .onChange(of: logFilter) { _, newValue in
            if newValue == .debug {
                flushPendingDebugLogs(immediate: true)
            } else {
                pendingDebugLogs.removeAll(keepingCapacity: true)
                debugFlushTask?.cancel()
                debugFlushTask = nil
                debugAggregator.reset()
            }
        }
        .onChange(of: availableSessions.count) { _, _ in
            guard let session = selectedSession else {
                selectedSessionID = availableSessions.first?.id
                return
            }
            if !availableSessions.contains(where: { $0.id == session.id }) {
                selectedSessionID = availableSessions.first?.id
            }
        }
    }

    internal var filteredLogs: [StreamingLogEntry] {
        switch logFilter {
        case .simple:
            return logs.filter { !$0.isDebug }
        case .debug:
            return logs
        }
    }
}

private final class StreamingTestHarnessDatabaseSession: DatabaseSession, @unchecked Sendable {
    func close() async {}
    func simpleQuery(_ sql: String) async throws -> QueryResultSet { QueryResultSet(columns: []) }
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet { try await simpleQuery(sql) }
    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet { try await simpleQuery(sql) }
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] { [] }
    func listDatabases() async throws -> [String] { ["analytics"] }
    func listSchemas() async throws -> [String] { ["public"] }
    func listExtensions() async throws -> [SchemaObjectInfo] { [] }
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet { try await simpleQuery(sql) }
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] { [] }
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String { "-- preview" }
    func executeUpdate(_ sql: String) async throws -> Int { 0 }
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails { TableStructureDetails() }
    func renameTable(schema: String?, oldName: String, newName: String) async throws {}
    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {}
    func truncateTable(schema: String?, name: String) async throws {}
    func rebuildIndex(schema: String, table: String, index: String) async throws {}
    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {}
    func analyzeTable(schema: String, table: String) async throws {}
    func reindexTable(schema: String, table: String) async throws {}
    func sessionForDatabase(_ database: String) async throws -> DatabaseSession { self }
    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring { fatalError("Not supported in test harness") }
    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] { [] }
    func isSuperuser() async throws -> Bool { false }
}
