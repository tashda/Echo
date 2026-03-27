import Foundation
import PostgresKit

@Observable
final class TablePropertiesViewModel {
    let connectionSessionID: UUID
    let schemaName: String
    let tableName: String
    let databaseType: DatabaseType

    var isLoading = false
    var isSubmitting = false
    var didComplete = false
    var errorMessage: String?

    // MARK: - Shared

    var rowCount: Int = 0
    var totalSizeBytes: Int64 = 0
    var tableSizeBytes: Int64 = 0
    var indexesSizeBytes: Int64 = 0

    // MARK: - PostgreSQL

    var pgOwner: String = ""
    var pgTablespace: String?
    var pgOid: Int = 0
    var pgDescription: String?
    var pgHasIndexes = false
    var pgHasTriggers = false
    var pgRowSecurity = false
    var pgIsPartitioned = false
    var pgOptions: [String]?

    // Postgres Storage (editable)
    var pgFillfactor: String = ""
    var pgToastTupleTarget: String = ""
    var pgParallelWorkers: String = ""
    var pgAutovacuumEnabled = true
    var pgEditableTablespace: String = ""

    // MARK: - MSSQL General

    var mssqlCreatedDate: String?
    var mssqlModifiedDate: String?
    var mssqlIsSystemObject = false
    var mssqlUsesAnsiNulls = false
    var mssqlIsReplicated = false
    var mssqlLockEscalation: String?
    var mssqlIsMemoryOptimized = false
    var mssqlDurability: String?

    // MARK: - MSSQL Storage

    var mssqlDataCompression: String?
    var mssqlFilegroup: String?
    var mssqlTextFilegroup: String?
    var mssqlFilestreamFilegroup: String?
    var mssqlIsPartitioned = false
    var mssqlPartitionScheme: String?
    var mssqlPartitionColumn: String?
    var mssqlPartitionCount: Int?

    // MARK: - MSSQL Temporal

    var mssqlIsSystemVersioned = false
    var mssqlHistoryTableSchema: String?
    var mssqlHistoryTableName: String?
    var mssqlPeriodStartColumn: String?
    var mssqlPeriodEndColumn: String?

    // MARK: - MSSQL Change Tracking

    var mssqlChangeTrackingEnabled = false
    var mssqlTrackColumnsUpdated = false

    // MARK: - Snapshot

    private var storageSnapshot: StorageSnapshot?

    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var environmentState: EnvironmentState?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    var isPostgres: Bool { databaseType == .postgresql }
    var isMSSQL: Bool { databaseType == .microsoftSQL }

    var pages: [TablePropertiesPage] {
        TablePropertiesPage.pages(
            for: databaseType,
            isSystemVersioned: mssqlIsSystemVersioned,
            changeTrackingEnabled: mssqlChangeTrackingEnabled
        )
    }

    var hasChanges: Bool {
        guard isPostgres, let snap = storageSnapshot else { return false }
        return pgFillfactor != snap.fillfactor
            || pgToastTupleTarget != snap.toastTupleTarget
            || pgParallelWorkers != snap.parallelWorkers
            || pgAutovacuumEnabled != snap.autovacuumEnabled
            || pgEditableTablespace != snap.tablespace
    }

    var isFormValid: Bool { true }

    init(connectionSessionID: UUID, schemaName: String, tableName: String, databaseType: DatabaseType) {
        self.connectionSessionID = connectionSessionID
        self.schemaName = schemaName
        self.tableName = tableName
        self.databaseType = databaseType
    }

    func loadProperties(session: ConnectionSession) async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let pg = session.session as? PostgresSession {
                try await loadPostgresProperties(pg)
            } else {
                try await loadMSSQLProperties(session: session)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitChanges(session: ConnectionSession) async throws {
        guard isPostgres, let pg = session.session as? PostgresSession else { return }
        let handle = activityEngine?.begin("Updating table properties", connectionSessionID: connectionSessionID)

        do {
            if let ff = Int(pgFillfactor), ff > 0 {
                try await pg.client.admin.alterTableSetParameter(table: tableName, parameter: "fillfactor", value: String(ff), schema: schemaName)
            }
            if let tt = Int(pgToastTupleTarget), tt > 0 {
                try await pg.client.admin.alterTableSetParameter(table: tableName, parameter: "toast_tuple_target", value: String(tt), schema: schemaName)
            }
            if let pw = Int(pgParallelWorkers), pw >= 0 {
                try await pg.client.admin.alterTableSetParameter(table: tableName, parameter: "parallel_workers", value: String(pw), schema: schemaName)
            }
            try await pg.client.admin.alterTableSetParameter(table: tableName, parameter: "autovacuum_enabled", value: pgAutovacuumEnabled ? "true" : "false", schema: schemaName)
            let ts = pgEditableTablespace.trimmingCharacters(in: .whitespacesAndNewlines)
            if !ts.isEmpty {
                try await pg.client.admin.alterTableSetTablespace(table: tableName, tablespace: ts, schema: schemaName)
            }
            handle?.succeed()
            try await loadPostgresProperties(pg)
        } catch {
            handle?.fail(error.localizedDescription)
            throw error
        }
    }

    func takeSnapshot() {
        storageSnapshot = StorageSnapshot(
            fillfactor: pgFillfactor,
            toastTupleTarget: pgToastTupleTarget,
            parallelWorkers: pgParallelWorkers,
            autovacuumEnabled: pgAutovacuumEnabled,
            tablespace: pgEditableTablespace
        )
    }

    // MARK: - PostgreSQL

    private func loadPostgresProperties(_ pg: PostgresSession) async throws {
        let details = try await pg.client.introspection.fetchTableDetails(schema: schemaName, table: tableName)
        pgOwner = details.owner
        pgTablespace = details.tablespace
        pgOid = details.oid
        pgDescription = details.description
        pgHasIndexes = details.hasIndexes
        pgHasTriggers = details.hasTriggers
        pgRowSecurity = details.rowSecurity
        pgIsPartitioned = details.isPartitioned
        rowCount = details.estimatedRowCount
        totalSizeBytes = details.totalSizeBytes
        tableSizeBytes = details.tableSizeBytes
        indexesSizeBytes = details.indexesSizeBytes
        pgOptions = details.options

        let props = try await pg.client.introspection.tableProperties(schema: schemaName, table: tableName)
        pgFillfactor = props.fillfactor.map(String.init) ?? ""
        pgToastTupleTarget = props.toastTupleTarget.map(String.init) ?? ""
        pgParallelWorkers = props.parallelWorkers.map(String.init) ?? ""
        pgAutovacuumEnabled = props.autovacuumEnabled ?? true
        pgEditableTablespace = props.tablespace ?? ""

        takeSnapshot()
    }

    // MARK: - MSSQL

    private func loadMSSQLProperties(session: ConnectionSession) async throws {
        let dbSession = session.session
        let details = try await dbSession.getTableStructureDetails(schema: schemaName, table: tableName)
        if let props = details.tableProperties {
            // General
            mssqlCreatedDate = props.createdDate
            mssqlModifiedDate = props.modifiedDate
            mssqlIsSystemObject = props.isSystemObject ?? false
            mssqlUsesAnsiNulls = props.usesAnsiNulls ?? false
            mssqlIsReplicated = props.isReplicated ?? false
            mssqlLockEscalation = props.lockEscalation
            mssqlIsMemoryOptimized = props.isMemoryOptimized ?? false
            mssqlDurability = props.memoryOptimizedDurability

            // Storage
            mssqlDataCompression = props.dataCompression
            mssqlFilegroup = props.filegroup
            mssqlTextFilegroup = props.textFilegroup
            mssqlFilestreamFilegroup = props.filestreamFilegroup
            mssqlIsPartitioned = props.isPartitioned ?? false
            mssqlPartitionScheme = props.partitionScheme
            mssqlPartitionColumn = props.partitionColumn
            mssqlPartitionCount = props.partitionCount

            // Temporal
            mssqlIsSystemVersioned = props.isSystemVersioned ?? false
            mssqlHistoryTableSchema = props.historyTableSchema
            mssqlHistoryTableName = props.historyTableName
            mssqlPeriodStartColumn = props.periodStartColumn
            mssqlPeriodEndColumn = props.periodEndColumn

            // Change Tracking
            mssqlChangeTrackingEnabled = props.changeTrackingEnabled ?? false
            mssqlTrackColumnsUpdated = props.trackColumnsUpdated ?? false
        }

        // Load size via sp_spaceused
        let sql = "EXEC sp_spaceused N'[\(schemaName)].[\(tableName)]'"
        if let result = try? await dbSession.simpleQuery(sql), let row = result.rows.first {
            let colNames = result.columns.map(\.name)
            func val(_ name: String) -> String? {
                guard let idx = colNames.firstIndex(of: name), idx < row.count else { return nil }
                return row[idx]
            }
            rowCount = Int(val("rows")?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            totalSizeBytes = parseMSSQLSize(val("reserved"))
            tableSizeBytes = parseMSSQLSize(val("data"))
            indexesSizeBytes = parseMSSQLSize(val("index_size"))
        }
    }

    private func parseMSSQLSize(_ value: String?) -> Int64 {
        guard let value else { return 0 }
        let cleaned = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " KB", with: "")
        return (Int64(cleaned) ?? 0) * 1024
    }
}

// MARK: - Storage Snapshot

private struct StorageSnapshot {
    let fillfactor: String
    let toastTupleTarget: String
    let parallelWorkers: String
    let autovacuumEnabled: Bool
    let tablespace: String
}
