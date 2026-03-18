import Foundation
import SwiftUI
import SQLServerKit

@MainActor
@Observable
final class MSSQLMaintenanceViewModel {
    enum MaintenanceSection: String, CaseIterable, Identifiable {
        case health = "Health & Integrity"
        case indexes = "Indexes"
        case backups = "Backup History"
        case extendedEvents = "Extended Events"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .health: return "checkmark.shield"
            case .indexes: return "rectangle.stack"
            case .backups: return "archivebox"
            case .extendedEvents: return "waveform.path.ecg"
            }
        }
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored private let session: DatabaseSession
    @ObservationIgnored private let notificationEngine: NotificationEngine?
    
    var selectedSection: MaintenanceSection = .health
    var selectedDatabase: String?
    var databaseList: [String] = []
    var isRefreshingDatabases = false
    var isInitialLoading = true
    var isInitialized = false
    
    // Health State
    var healthStats: SQLServerDatabaseHealth?
    var isCheckingIntegrity = false
    var isShrinking = false
    
    // Index State
    var fragmentedIndexes: [SQLServerIndexFragmentation] = []
    var isRefreshingIndexes = false
    
    // Backup State
    var backupHistory: [SQLServerBackupHistoryEntry] = []
    var isRefreshingBackups = false
    
    // Extended Events Integration
    var extendedEventsVM: ExtendedEventsViewModel?

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
        
        // Initialize XE sub-viewmodel if we have an MSSQL session
        if let mssql = session as? MSSQLSession {
            self.extendedEventsVM = ExtendedEventsViewModel(
                xeClient: mssql.extendedEvents,
                connectionSessionID: connectionSessionID
            )
        }
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
        case .indexes:
            await refreshIndexes()
        case .backups:
            await refreshBackups()
        case .extendedEvents:
            await extendedEventsVM?.loadSessions()
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
        } catch {
            healthStats = nil
            notificationEngine?.post(category: .maintenanceFailed, message: "Failed to load health stats: \(error.localizedDescription)")
        }
    }

    func runIntegrityCheck() async {
        isCheckingIntegrity = true
        defer { isCheckingIntegrity = false }
        do {
            let result = try await session.checkDatabaseIntegrity()
            notificationEngine?.post(
                category: .maintenanceCompleted,
                message: result.succeeded
                    ? "Integrity check completed successfully for \(selectedDatabase ?? "database")."
                    : "Integrity check finished with issues: \(result.messages.first ?? "Unknown")"
            )
            await refreshHealth()
        } catch {
            notificationEngine?.post(
                category: .maintenanceFailed,
                message: "Integrity check failed: \(error.localizedDescription)"
            )
        }
    }

    func runShrink() async {
        let sizeBefore = healthStats?.sizeMB ?? 0
        isShrinking = true
        defer { isShrinking = false }
        do {
            _ = try await session.shrinkDatabase()
            await refreshHealth()
            let sizeAfter = healthStats?.sizeMB ?? 0
            notificationEngine?.post(
                category: .maintenanceCompleted,
                message: "Database shrunk from \(String(format: "%.1f", sizeBefore)) MB to \(String(format: "%.1f", sizeAfter)) MB."
            )
        } catch {
            notificationEngine?.post(
                category: .maintenanceFailed,
                message: "Shrink failed: \(error.localizedDescription)"
            )
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
        do {
            let result = try await session.rebuildIndex(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                notificationEngine?.post(category: .indexRebuilt, message: "Index \(index.indexName) rebuilt successfully.")
                await refreshIndexes()
            } else {
                notificationEngine?.post(category: .indexRebuildFailed, message: "Failed to rebuild index \(index.indexName): \(result.messages.first ?? "Unknown error")")
            }
        } catch {
            notificationEngine?.post(category: .indexRebuildFailed, message: "Failed to rebuild index \(index.indexName): \(error.localizedDescription)")
        }
    }

    func updateStatistics(_ index: SQLServerIndexFragmentation) async {
        do {
            let result = try await session.updateIndexStatistics(schema: index.schemaName, table: index.tableName, index: index.indexName)
            if result.succeeded {
                notificationEngine?.post(category: .maintenanceCompleted, message: "Statistics updated for index \(index.indexName) on table \(index.tableName).")
                await refreshIndexes()
            } else {
                notificationEngine?.post(category: .maintenanceFailed, message: "Failed to update statistics: \(result.messages.first ?? "Unknown error")")
            }
        } catch {
            notificationEngine?.post(category: .maintenanceFailed, message: "Failed to update statistics: \(error.localizedDescription)")
        }
    }

    // MARK: - Backup Operations

    func refreshBackups() async {
        isRefreshingBackups = true
        defer { isRefreshingBackups = false }
        do {
            backupHistory = try await session.getBackupHistory(limit: 50)
        } catch {
            backupHistory = []
        }
    }

    func estimatedMemoryUsageBytes() -> Int {
        let healthSize = 1024 // Model
        let indexSize = fragmentedIndexes.count * 256
        let backupSize = backupHistory.count * 256
        let xeSize = extendedEventsVM?.estimatedMemoryUsageBytes() ?? 0
        return 1024 * 64 + healthSize + indexSize + backupSize + xeSize
    }
}
