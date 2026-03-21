import Foundation
import SwiftUI
import SQLServerKit

@MainActor
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
    @ObservationIgnored private let session: DatabaseSession
    @ObservationIgnored private let notificationEngine: NotificationEngine?
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

    private func logOperation(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Maintenance", duration: TimeInterval? = nil) {
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
            
            // If we don't have a selected database but we have a list, use the current one or first one
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

    // MARK: - Health Operations

    func refreshHealth() async {
        do {
            // Ensure database context is set before querying
            if let db = selectedDatabase {
                _ = try await session.sessionForDatabase(db)
            }
            healthStats = try await session.getDatabaseHealth()
            healthPermissionError = nil
        } catch {
            healthStats = nil
            let msg = "\(error)"
            if msg.contains("permission was denied") || msg.contains("not have permission") {
                healthPermissionError = "Health statistics require access to the master database (sys.master_files)."
            } else {
                healthPermissionError = nil
                notificationEngine?.post(category: .maintenanceFailed, message: "Failed to load health stats: \(error.localizedDescription)")
            }
        }
    }

    func runIntegrityCheck() async {
        let db = selectedDatabase ?? "database"
        isCheckingIntegrity = true
        defer { isCheckingIntegrity = false }
        let handle = activityEngine?.begin("Integrity check \(db)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC CHECKDB(N'\(db)')", category: "Integrity Check")
        do {
            let result = try await session.checkDatabaseIntegrity()
            for msg in result.messages {
                logOperation(msg, severity: result.succeeded ? .info : .warning, category: "Integrity Check")
            }
            let summary = result.succeeded
                ? "Integrity check completed successfully for \(db)."
                : "Integrity check finished with issues: \(result.messages.first ?? "Unknown")"
            logOperation(summary, severity: result.succeeded ? .success : .warning, category: "Integrity Check")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            if result.succeeded { handle?.succeed() } else { handle?.fail(summary) }
            await refreshHealth()
        } catch {
            logOperation("Integrity check failed: \(error.localizedDescription)", severity: .error, category: "Integrity Check")
            notificationEngine?.post(category: .maintenanceFailed, message: "Integrity check failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func runShrink() async {
        let db = selectedDatabase ?? "database"
        let sizeBefore = healthStats?.sizeMB ?? 0
        isShrinking = true
        defer { isShrinking = false }
        let handle = activityEngine?.begin("Shrink \(db)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC SHRINKDATABASE(N'\(db)')", category: "Shrink Database")
        do {
            _ = try await session.shrinkDatabase()
            await refreshHealth()
            let sizeAfter = healthStats?.sizeMB ?? 0
            let summary = "Database shrunk from \(String(format: "%.1f", sizeBefore)) MB to \(String(format: "%.1f", sizeAfter)) MB."
            logOperation(summary, severity: .success, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            handle?.succeed()
        } catch {
            logOperation("Shrink failed: \(error.localizedDescription)", severity: .error, category: "Shrink Database")
            notificationEngine?.post(category: .maintenanceFailed, message: "Shrink failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Table Operations

    func refreshTables() async {
        isRefreshingTables = true
        defer { isRefreshingTables = false }
        do {
            if let db = selectedDatabase {
                _ = try await session.sessionForDatabase(db)
            }
            tableStats = try await session.listTableStats()
        } catch {
            // Keep existing data if refresh fails
        }
    }

    func updateTableStats(_ table: SQLServerTableStat) async {
        let handle = activityEngine?.begin("Update stats \(table.tableName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: UPDATE STATISTICS [\(table.schemaName)].[\(table.tableName)]", category: "Update Statistics")
        do {
            let result = try await session.updateTableStatistics(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "Statistics updated for table \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to update statistics: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to update statistics: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Update Statistics")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func checkTable(_ table: SQLServerTableStat) async {
        let handle = activityEngine?.begin("Check table \(table.tableName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: DBCC CHECKTABLE('[\(table.schemaName)].[\(table.tableName)]')", category: "Check Table")
        do {
            let result = try await session.checkTable(schema: table.schemaName, table: table.tableName)
            for msg in result.messages {
                logOperation(msg, severity: result.succeeded ? .info : .warning, category: "Check Table")
            }
            let summary = result.succeeded
                ? "Table check completed successfully for \(table.schemaName).\(table.tableName)."
                : "Table check finished with issues: \(result.messages.first ?? "Unknown")"
            logOperation(summary, severity: result.succeeded ? .success : .warning, category: "Check Table")
            notificationEngine?.post(category: .maintenanceCompleted, message: summary)
            if result.succeeded { handle?.succeed() } else { handle?.fail(summary) }
        } catch {
            logOperation("Table check failed: \(error.localizedDescription)", severity: .error, category: "Check Table")
            notificationEngine?.post(category: .maintenanceFailed, message: "Table check failed: \(error.localizedDescription)")
            handle?.fail(error.localizedDescription)
        }
    }

    func rebuildTable(_ table: SQLServerTableStat) async {
        let label = "Rebuild \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER TABLE [\(table.schemaName)].[\(table.tableName)] REBUILD", category: "Rebuild Table")
        do {
            let result = try await session.rebuildTable(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "Table rebuilt for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Rebuild Table")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild table: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Rebuild Table")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild table: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Rebuild Table")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func rebuildAllIndexes(_ table: SQLServerTableStat) async {
        let label = "Rebuild indexes \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX ALL ON [\(table.schemaName)].[\(table.tableName)] REBUILD", category: "Rebuild Indexes")
        do {
            let result = try await session.rebuildIndexes(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "All indexes rebuilt for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Rebuild Indexes")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild indexes: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Rebuild Indexes")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild indexes: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Rebuild Indexes")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func reorganizeAllIndexes(_ table: SQLServerTableStat) async {
        let label = "Reorganize indexes \(table.schemaName).\(table.tableName)"
        let handle = activityEngine?.begin(label, connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX ALL ON [\(table.schemaName)].[\(table.tableName)] REORGANIZE", category: "Reorganize Indexes")
        do {
            let result = try await session.reorganizeIndexes(schema: table.schemaName, table: table.tableName)
            if result.succeeded {
                await refreshTables()
                let msg = "All indexes reorganized for \(table.schemaName).\(table.tableName)."
                logOperation(msg, severity: .success, category: "Reorganize Indexes")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to reorganize indexes: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Reorganize Indexes")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to reorganize indexes: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Reorganize Indexes")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Index Operations

    func refreshIndexes() async {
        isRefreshingIndexes = true
        defer { isRefreshingIndexes = false }
        do {
            // Ensure database context is set before querying
            if let db = selectedDatabase {
                _ = try await session.sessionForDatabase(db)
            }
            fragmentedIndexes = try await session.listFragmentedIndexes()
        } catch {
            // Keep existing data if refresh fails
        }
    }

    func rebuildIndex(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Rebuild \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX [\(index.indexName)] ON [\(index.schemaName)].[\(index.tableName)] REBUILD", category: "Index Rebuild")
        do {
            let result = try await session.rebuildIndex(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Index \(index.indexName) rebuilt successfully."
                logOperation(msg, severity: .success, category: "Index Rebuild")
                notificationEngine?.post(category: .indexRebuilt, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to rebuild index \(index.indexName): \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Index Rebuild")
                notificationEngine?.post(category: .indexRebuildFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to rebuild index \(index.indexName): \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Index Rebuild")
            notificationEngine?.post(category: .indexRebuildFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func reorganizeIndex(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Reorganize \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: ALTER INDEX [\(index.indexName)] ON [\(index.schemaName)].[\(index.tableName)] REORGANIZE", category: "Index Reorganize")
        do {
            let result = try await session.reorganizeIndex(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Index \(index.indexName) reorganized successfully."
                logOperation(msg, severity: .success, category: "Index Reorganize")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to reorganize index \(index.indexName): \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Index Reorganize")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to reorganize index \(index.indexName): \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Index Reorganize")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    func updateStatistics(_ index: SQLServerIndexFragmentation) async {
        let handle = activityEngine?.begin("Update stats \(index.indexName)", connectionSessionID: connectionSessionID)
        logOperation("Executing: UPDATE STATISTICS [\(index.schemaName)].[\(index.tableName)] [\(index.indexName)]", category: "Update Statistics")
        do {
            let result = try await session.updateIndexStatistics(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                await refreshIndexes()
                let msg = "Statistics updated for index \(index.indexName) on table \(index.tableName)."
                logOperation(msg, severity: .success, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceCompleted, message: msg)
                handle?.succeed()
            } else {
                let msg = "Failed to update statistics: \(result.messages.first ?? "Unknown error")"
                logOperation(msg, severity: .error, category: "Update Statistics")
                notificationEngine?.post(category: .maintenanceFailed, message: msg)
                handle?.fail(msg)
            }
        } catch {
            let msg = "Failed to update statistics: \(error.localizedDescription)"
            logOperation(msg, severity: .error, category: "Update Statistics")
            notificationEngine?.post(category: .maintenanceFailed, message: msg)
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Backup Operations

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
        let healthSize = 1024 // Model
        let tableSize = tableStats.count * 256
        let indexSize = fragmentedIndexes.count * 256
        let backupSize = backupHistory.count * 256
        return 1024 * 64 + healthSize + tableSize + indexSize + backupSize
    }
}
