import Foundation
import PostgresKit
import SQLServerKit

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

    // MARK: - MySQL

    var mysqlEngine: String = ""
    var mysqlCharacterSet: String = ""
    var mysqlCollation: String = ""
    var mysqlAutoIncrement: String = ""
    var mysqlRowFormat: String = ""
    var mysqlComment: String = ""

    // MARK: - Snapshot

    private var storageSnapshot: StorageSnapshot?

    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var environmentState: EnvironmentState?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    var isPostgres: Bool { databaseType == .postgresql }
    var isMySQL: Bool { databaseType == .mysql }
    var isMSSQL: Bool { databaseType == .microsoftSQL }

    var pages: [TablePropertiesPage] {
        TablePropertiesPage.pages(
            for: databaseType,
            isSystemVersioned: mssqlIsSystemVersioned,
            changeTrackingEnabled: mssqlChangeTrackingEnabled
        )
    }

    var hasChanges: Bool {
        guard let snap = storageSnapshot else { return false }
        if isPostgres {
            return pgFillfactor != snap.fillfactor
                || pgToastTupleTarget != snap.toastTupleTarget
                || pgParallelWorkers != snap.parallelWorkers
                || pgAutovacuumEnabled != snap.autovacuumEnabled
                || pgEditableTablespace != snap.tablespace
        }
        if isMySQL {
            return mysqlEngine != snap.mysqlEngine
                || mysqlCharacterSet != snap.mysqlCharacterSet
                || mysqlCollation != snap.mysqlCollation
                || mysqlAutoIncrement != snap.mysqlAutoIncrement
                || mysqlRowFormat != snap.mysqlRowFormat
                || mysqlComment != snap.mysqlComment
        }
        return false
    }

    var isFormValid: Bool {
        let autoIncrement = mysqlAutoIncrement.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !isMySQL || !autoIncrement.isEmpty else { return true }
        return Int(autoIncrement) != nil
    }

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
            } else if session.connection.databaseType == .mysql {
                try await loadMySQLProperties(session: session)
            } else {
                try await loadMSSQLProperties(session: session)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitChanges(session: ConnectionSession) async throws {
        let handle = activityEngine?.begin("Updating table properties", connectionSessionID: connectionSessionID)

        do {
            if isPostgres, let pg = session.session as? PostgresSession {
                try await submitPostgresChanges(pg)
                try await loadPostgresProperties(pg)
            } else if isMySQL {
                try await submitMySQLChanges(session: session)
                try await loadMySQLProperties(session: session)
            }
            handle?.succeed()
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
            tablespace: pgEditableTablespace,
            mysqlEngine: mysqlEngine,
            mysqlCharacterSet: mysqlCharacterSet,
            mysqlCollation: mysqlCollation,
            mysqlAutoIncrement: mysqlAutoIncrement,
            mysqlRowFormat: mysqlRowFormat,
            mysqlComment: mysqlComment
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

    // MARK: - MySQL

    private func loadMySQLProperties(session: ConnectionSession) async throws {
        let details = try await session.session.getTableStructureDetails(schema: schemaName, table: tableName)
        mysqlEngine = ""
        mysqlCharacterSet = ""
        mysqlCollation = ""
        mysqlAutoIncrement = ""
        mysqlRowFormat = ""
        mysqlComment = ""
        rowCount = 0
        tableSizeBytes = 0
        indexesSizeBytes = 0
        totalSizeBytes = 0
        if let props = details.tableProperties {
            mysqlEngine = props.storageEngine ?? ""
            mysqlCharacterSet = props.characterSet ?? ""
            mysqlCollation = props.collation ?? ""
            mysqlAutoIncrement = props.autoIncrementValue.map(String.init) ?? ""
            mysqlRowFormat = props.rowFormat ?? ""
            mysqlComment = props.tableComment ?? ""
            rowCount = Int(props.estimatedRowCount ?? 0)
            tableSizeBytes = props.dataLengthBytes ?? 0
            indexesSizeBytes = props.indexLengthBytes ?? 0
            totalSizeBytes = tableSizeBytes + indexesSizeBytes
        }

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

        // Load size via typed spaceUsed API
        if let mssql = dbSession as? MSSQLSession,
           let spaceUsed = try? await mssql.admin.spaceUsed(schema: schemaName, table: tableName) {
            rowCount = Int(spaceUsed.rows.trimmingCharacters(in: .whitespaces)) ?? 0
            totalSizeBytes = parseMSSQLSize(spaceUsed.reserved)
            tableSizeBytes = parseMSSQLSize(spaceUsed.data)
            indexesSizeBytes = parseMSSQLSize(spaceUsed.indexSize)
        }
    }

    private func parseMSSQLSize(_ value: String?) -> Int64 {
        guard let value else { return 0 }
        let cleaned = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " KB", with: "")
        return (Int64(cleaned) ?? 0) * 1024
    }

    // MARK: - Shared Submit

    private func submitPostgresChanges(_ pg: PostgresSession) async throws {
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
    }

    private func submitMySQLChanges(session: ConnectionSession) async throws {
        let qualifiedTable = MySQLDialectGenerator(schema: schemaName).qualifiedTable(schema: schemaName, table: tableName)
        let statements = MySQLDialectGenerator(schema: schemaName).alterTableProperties(
            table: qualifiedTable,
            properties: mysqlPropertyAssignments()
        )
        for statement in statements {
            _ = try await session.session.executeUpdate(statement)
        }
    }

    private func mysqlPropertyAssignments() -> [(key: String, value: String)] {
        var properties: [(key: String, value: String)] = []

        let engine = mysqlEngine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !engine.isEmpty {
            properties.append(("ENGINE", engine))
        }

        let characterSet = mysqlCharacterSet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !characterSet.isEmpty {
            properties.append(("CHARACTER SET", characterSet))
        }

        let collation = mysqlCollation.trimmingCharacters(in: .whitespacesAndNewlines)
        if !collation.isEmpty {
            properties.append(("COLLATE", collation))
        }

        let autoIncrement = mysqlAutoIncrement.trimmingCharacters(in: .whitespacesAndNewlines)
        if !autoIncrement.isEmpty {
            properties.append(("AUTO_INCREMENT", autoIncrement))
        }

        let rowFormat = mysqlRowFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        if !rowFormat.isEmpty {
            properties.append(("ROW_FORMAT", rowFormat))
        }

        properties.append(("COMMENT", mysqlComment.mysqlSQLLiteral))
        return properties
    }
}

// MARK: - Storage Snapshot

private struct StorageSnapshot {
    let fillfactor: String
    let toastTupleTarget: String
    let parallelWorkers: String
    let autovacuumEnabled: Bool
    let tablespace: String
    let mysqlEngine: String
    let mysqlCharacterSet: String
    let mysqlCollation: String
    let mysqlAutoIncrement: String
    let mysqlRowFormat: String
    let mysqlComment: String
}

private extension String {
    var mysqlSQLLiteral: String {
        let escaped = replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        return "'\(escaped)'"
    }
}
