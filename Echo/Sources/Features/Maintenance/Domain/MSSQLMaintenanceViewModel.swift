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

        var id: String { rawValue }
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
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
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
        self.backupsVM?.panelState = state
    }

    func logOperation(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Maintenance", duration: TimeInterval? = nil) {
        guard let panelState else { return }
        panelState.appendMessage(text, severity: severity, category: category, duration: duration)
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
                _ = try? await session.sessionForDatabase(db)
                await loadCurrentSection()
            }
        } catch {
            databaseList = []
        }
    }

    func selectDatabase(_ database: String) async {
        guard selectedDatabase != database else { return }
        selectedDatabase = database
        backupsVM?.databaseName = database
        backupsVM?.restoreDatabaseName = database
        isInitialized = false
        do {
            _ = try await session.sessionForDatabase(database)
            await loadCurrentSection()
            isInitialized = true
        } catch {
            isInitialized = true
            notificationEngine?.post(category: .databaseSwitchFailed, message: "Failed to switch database: \(error.localizedDescription)")
        }
    }

    func refresh() async {
        await loadCurrentSection()
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
        }
    }

    func refreshBackups() async {
        isRefreshingBackups = true
        defer { isRefreshingBackups = false }
        do {
            backupHistory = try await session.getBackupHistory(limit: 50)
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
        return 1024 * 64 + healthSize + tableSize + indexSize + backupSize
    }
}
