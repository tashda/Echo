import Foundation
import SwiftUI
import SQLServerKit

@Observable
final class MSSQLMaintenanceViewModel {
    enum MaintenanceSection: String, CaseIterable, Identifiable {
        case health = "Health"
        case tables = "Tables"
        case indexes = "Indexes"
        case backups = "Backups"
        case queryStore = "Query Store"

        var id: String { rawValue }
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var activeSession: DatabaseSession?
    @ObservationIgnored let notificationEngine: NotificationEngine?
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: MaintenanceSection = .health
    var selectedDatabase: String?
    var databaseList: [String] = []
    var isRefreshingDatabases = false
    var isInitialLoading = true
    var isInitialized = false

    // Health State
    var healthStats: SQLServerDatabaseHealth?
    var healthPermissionError: String?
    var isCheckingIntegrity = false
    var isShrinking = false
    var isShrinkingFile = false

    // Shrink Options
    var shrinkTargetPercent: Int = 10
    var shrinkOption: ShrinkOptionChoice = .defaultBehavior
    var databaseFiles: [SQLServerDatabaseFile] = []
    var shrinkFileName: String = ""
    var shrinkFileTargetMB: Int = 0
    var isLoadingFiles = false

    // Table State
    var tableStats: [SQLServerTableStat] = []
    var isRefreshingTables = false

    // Index State
    var fragmentedIndexes: [SQLServerIndexFragmentation] = []
    var isRefreshingIndexes = false

    // Backup State
    var backupHistory: [SQLServerBackupHistoryEntry] = []
    var backupPermissionError: String?
    var isRefreshingBackups = false
    var backupsActiveForm: MSSQLBackupRestoreViewModel.ActiveForm?
    var backupsVM: MSSQLBackupRestoreViewModel?

    // Query Store State
    var queryStoreVM: QueryStoreViewModel?

    init(
        session: DatabaseSession,
        connectionID: UUID,
        connectionSessionID: UUID,
        initialDatabase: String? = nil,
        notificationEngine: NotificationEngine? = nil
    ) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
        self.selectedDatabase = initialDatabase
        self.notificationEngine = notificationEngine
        self.backupsVM = MSSQLBackupRestoreViewModel(session: session, databaseName: initialDatabase ?? "")
        if let db = initialDatabase, !db.isEmpty, let mssql = session as? MSSQLSession {
            self.queryStoreVM = QueryStoreViewModel(
                queryStoreClient: mssql.queryStore,
                databaseName: db,
                connectionSessionID: connectionSessionID
            )
        }
    }

    func recreateQueryStoreVM(databaseName: String) {
        guard let mssql = session as? MSSQLSession, !databaseName.isEmpty else {
            queryStoreVM = nil
            return
        }
        queryStoreVM = QueryStoreViewModel(
            queryStoreClient: mssql.queryStore,
            databaseName: databaseName,
            connectionSessionID: connectionSessionID
        )
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
        self.backupsVM?.panelState = state
    }

    func logOperation(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Maintenance", duration: TimeInterval? = nil) {
        guard let panelState else { return }
        panelState.appendMessage(text, severity: severity, category: category, duration: duration)
    }

    /// Returns the session for the currently selected database, caching the result.
    func resolveSession() async throws -> DatabaseSession {
        if let active = activeSession { return active }
        guard let db = selectedDatabase else { return session }
        let resolved = try await session.sessionForDatabase(db)
        activeSession = resolved
        return resolved
    }

    func loadDatabases() async {
        isRefreshingDatabases = true
        defer {
            isRefreshingDatabases = false
            isInitialLoading = false
            isInitialized = true
        }
        do {
            databaseList = try await session.listDatabases()

            if selectedDatabase == nil || selectedDatabase?.isEmpty == true {
                if let current = try? await session.currentDatabaseName(), !current.isEmpty {
                    selectedDatabase = current
                } else {
                    selectedDatabase = databaseList.first
                }
            }

            if let db = selectedDatabase {
                if queryStoreVM == nil { recreateQueryStoreVM(databaseName: db) }
                activeSession = nil
                _ = try? await resolveSession()
                await loadAllSections()
            }
        } catch {
            databaseList = []
        }
    }

    func selectDatabase(_ database: String) async {
        guard selectedDatabase != database else { return }
        selectedDatabase = database
        activeSession = nil
        backupsVM?.databaseName = database
        backupsVM?.restoreDatabaseName = database
        recreateQueryStoreVM(databaseName: database)
        isInitialized = false
        do {
            _ = try await resolveSession()
            await loadAllSections()
            isInitialized = true
        } catch {
            isInitialized = true
            notificationEngine?.post(category: .databaseSwitchFailed, message: "Failed to switch database: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        await loadAllSections()
    }

    /// Loads all sections so every tab has data when the user switches.
    func loadAllSections() async {
        guard selectedDatabase != nil else { return }
        await refreshHealth()
        await refreshTables()
        await refreshIndexes()
        await refreshBackups()
    }

    func loadCurrentSection() async {
        guard selectedDatabase != nil else { return }

        switch selectedSection {
        case .health:
            await refreshHealth()
        case .tables:
            await refreshTables()
        case .indexes:
            await refreshIndexes()
        case .backups:
            await refreshBackups()
        case .queryStore:
            await queryStoreVM?.loadAll()
        }
    }

    func refreshBackups() async {
        isRefreshingBackups = true
        defer { isRefreshingBackups = false }
        do {
            let dbSession = try await resolveSession()
            backupHistory = try await dbSession.getBackupHistory(limit: 50)
            backupPermissionError = nil
        } catch {
            backupHistory = []
            let msg = "\(error)"
            if msg.contains("permission was denied") || msg.contains("not have permission") {
                backupPermissionError = "Backup history requires access to the msdb database."
            } else {
                backupPermissionError = nil
            }
        }
    }

    func estimatedMemoryUsageBytes() -> Int {
        let healthSize = 1024
        let tableSize = tableStats.count * 256
        let indexSize = fragmentedIndexes.count * 256
        let backupSize = backupHistory.count * 256
        let queryStoreSize = queryStoreVM?.estimatedMemoryUsageBytes() ?? 0
        return 1024 * 64 + healthSize + tableSize + indexSize + backupSize + queryStoreSize
    }
}
