import Foundation
import Logging
import SQLiteNIO
import NIOCore

struct SQLiteFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.sqlite")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        _ = authentication
        let resolvedPath = try resolveDatabasePath(host: host, database: database)
        do {
            let storage: SQLiteConnection.Storage = resolvedPath == ":memory:"
                ? .memory
                : .file(path: resolvedPath)
            let connection = try await SQLiteConnection.open(storage: storage, logger: logger)
            let session = SQLiteSession(logger: logger)
            await session.bootstrap(with: connection)
            return session
        } catch {
            throw DatabaseError.connectionFailed("Failed to open SQLite database: \(error.localizedDescription)")
        }
    }

    private func resolveDatabasePath(host: String, database: String?) throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var candidate = trimmedHost
        if candidate.isEmpty {
            candidate = trimmedDatabase
        }

        guard !candidate.isEmpty else {
            throw DatabaseError.connectionFailed("A database file path is required for SQLite connections")
        }

        if candidate == ":memory:" {
            return candidate
        }

        if candidate.hasPrefix("file:") {
            return candidate
        }

        let expanded = (candidate as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return expanded
        }

        let absolute = URL(fileURLWithPath: expanded, relativeTo: FileManager.default.currentDirectoryPathURL).path
        return absolute
    }
}

private extension FileManager {
    var currentDirectoryPathURL: URL {
        URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
}

private struct SQLiteRawColumn: Sendable {
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isNullable: Bool
    let maxLength: Int?
}

private struct SQLiteRawIndexColumn: Sendable {
    let name: String
    let position: Int
    let isAscending: Bool
}

private struct SQLiteRawIndex: Sendable {
    let name: String
    let isUnique: Bool
    let columns: [SQLiteRawIndexColumn]
    let filterCondition: String?
}

private struct SQLiteRawForeignKey: Sendable {
    let id: Int
    let referencedTable: String
    let columns: [String]
    let referencedColumns: [String]
    let onUpdate: String?
    let onDelete: String?
}

actor SQLiteSession: DatabaseSession {
    private var connection: SQLiteConnection?
    private let logger: Logger

    init(logger: Logger) {
        self.logger = logger
    }

    func bootstrap(with connection: SQLiteConnection) {
        self.connection = connection
    }

    func close() async {
        if let connection {
            do {
                try await connection.close()
            } catch {
                logger.warning("Failed to close SQLite connection: \(String(describing: error))")
            }
        }
        connection = nil
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        let connection = try requireConnection()

        let rows = try await connection.query(sql)
        var resolvedColumns: [ColumnInfo] = []
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        if let firstRow = rows.first {
            resolvedColumns = makeColumnInfo(from: firstRow)
        }

        var worker: ResultStreamBatchWorker?

        for row in rows {
            if worker == nil, let handler = progressHandler, !resolvedColumns.isEmpty {
                let bridgedHandler: QueryProgressHandler = { update in
                    Task { @MainActor in handler(update) }
                }
                worker = ResultStreamBatchWorker(
                    label: "dk.tippr.echo.sqlite.streamWorker",
                    columns: resolvedColumns,
                    streamingPreviewLimit: streamingPreviewLimit,
                    maxFlushLatency: maxFlushLatency,
                    operationStart: operationStart,
                    progressHandler: bridgedHandler
                )
            }

            let decodeStart = CFAbsoluteTimeGetCurrent()
            let rowValues = makeRow(from: row)
            let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart
            totalRowCount += 1
            if previewRows.count < streamingPreviewLimit {
                previewRows.append(rowValues)
            }
            let previewForWorker: [String?]? = totalRowCount <= streamingPreviewLimit ? rowValues : nil
            let encodedRow = ResultBinaryRowCodec.encode(row: rowValues)
            if let worker {
                worker.enqueue(
                    .init(
                        previewValues: previewForWorker,
                        storage: .encoded(encodedRow),
                        totalRowCount: totalRowCount,
                        decodeDuration: decodeDuration
                    )
                )
            }
        }

        if resolvedColumns.isEmpty {
            resolvedColumns = resolveColumnsForEmptyResult()
        }

        if resolvedColumns.isEmpty {
            resolvedColumns = [ColumnInfo(name: "result", dataType: "TEXT")]
        }

        if worker == nil, let handler = progressHandler, !resolvedColumns.isEmpty {
            let bridgedHandler: QueryProgressHandler = { update in
                Task { @MainActor in handler(update) }
            }
            worker = ResultStreamBatchWorker(
                label: "dk.tippr.echo.sqlite.streamWorker",
                columns: resolvedColumns,
                streamingPreviewLimit: streamingPreviewLimit,
                maxFlushLatency: maxFlushLatency,
                operationStart: operationStart,
                progressHandler: bridgedHandler
            )
        }

        worker?.finish(totalRowCount: totalRowCount)

        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let sql = """
        SELECT name, type
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """
        let rows = try await connection.query(sql)
        return await MainActor.run {
            rows.compactMap { row -> SchemaObjectInfo? in
                guard
                    let name = row.column("name")?.string,
                    let type = row.column("type")?.string,
                    let objectType = SchemaObjectInfo.ObjectType(sqliteType: type)
                else { return nil }
                return SchemaObjectInfo(name: name, schema: databaseName, type: objectType)
            }
        }
    }

    func listDatabases() async throws -> [String] {
        let connection = try requireConnection()
        let rows = try await connection.query("PRAGMA database_list;")
        let names = rows.compactMap { $0.column("name")?.string }
        return names.isEmpty ? [normalizedDatabaseName(nil)] : names
    }

    func listSchemas() async throws -> [String] {
        try await listDatabases()
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.hasSuffix(";") ? String(trimmed.dropLast()) : trimmed
        let pagedSQL = "\(base) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let pragma = "PRAGMA \(databaseName).table_info('\(escapeSingleQuotes(tableName))');"
        let rows = try await connection.query(pragma)

        let rawColumns = rows.compactMap { row -> SQLiteRawColumn? in
            guard let name = row.column("name")?.string else { return nil }
            let type = row.column("type")?.string ?? ""
            let notNull = (row.column("notnull")?.integer ?? 0) != 0
            let pk = (row.column("pk")?.integer ?? 0) != 0
            return SQLiteRawColumn(
                name: name,
                dataType: type.isEmpty ? "TEXT" : type,
                isPrimaryKey: pk,
                isNullable: !notNull,
                maxLength: nil
            )
        }

        return await MainActor.run {
            rawColumns.map { column in
                ColumnInfo(
                    name: column.name,
                    dataType: column.dataType,
                    isPrimaryKey: column.isPrimaryKey,
                    isNullable: column.isNullable,
                    maxLength: column.maxLength
                )
            }
        }
    }

    func getObjectDefinition(
        objectName: String,
        schemaName: String,
        objectType: SchemaObjectInfo.ObjectType
    ) async throws -> String {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let typeString: String
        switch objectType {
        case .table: typeString = "table"
        case .view: typeString = "view"
        case .trigger: typeString = "trigger"
        case .materializedView, .function, .procedure:
            throw DatabaseError.queryError("SQLite does not support definitions for \(objectType.rawValue)")
        }

        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = '\(typeString)'
          AND name = ?
        LIMIT 1;
        """

        let rows = try await connection.query(sql, [SQLiteData.text(objectName)])
        guard let definition = rows.first?.column("sql")?.string else {
            throw DatabaseError.queryError("Definition for \(objectName) was not found")
        }
        return definition
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let connection = try requireConnection()
        do {
            _ = try await connection.query(sql)
            let changeRows = try await connection.query("SELECT changes() AS changes;")
            return changeRows.first?.column("changes")?.integer ?? 0
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columnsInfo = try await getTableSchema(table, schemaName: schema)
        let rawIndexes = try await fetchIndexes(schema: schema, table: table)
        let rawForeignKeys = try await fetchForeignKeys(schema: schema, table: table)
        let normalizedSchemaName = normalizedDatabaseName(schema)

        return await MainActor.run {
            let columns = columnsInfo.map { column in
                TableStructureDetails.Column(
                    name: column.name,
                    dataType: column.dataType,
                    isNullable: column.isNullable,
                    defaultValue: nil,
                    generatedExpression: nil
                )
            }

            let primaryKeyColumns = columnsInfo.filter(\.isPrimaryKey).map(\.name)
            let primaryKey = primaryKeyColumns.isEmpty
                ? nil
                : TableStructureDetails.PrimaryKey(name: "primary_key", columns: primaryKeyColumns)

            let indexes = rawIndexes.map { index in
                let indexColumns = index.columns.map { column -> TableStructureDetails.Index.Column in
                    TableStructureDetails.Index.Column(
                        name: column.name,
                        position: column.position,
                        sortOrder: column.isAscending ? .ascending : .descending
                    )
                }
                return TableStructureDetails.Index(
                    name: index.name,
                    columns: indexColumns,
                    isUnique: index.isUnique,
                    filterCondition: index.filterCondition
                )
            }

            let uniqueConstraints = indexes
                .filter(\.isUnique)
                .map { TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns.map(\.name)) }

            let foreignKeys = rawForeignKeys.map { key in
                TableStructureDetails.ForeignKey(
                    name: "fk_\(table)_\(key.id)",
                    columns: key.columns,
                    referencedSchema: normalizedSchemaName,
                    referencedTable: key.referencedTable,
                    referencedColumns: key.referencedColumns,
                    onUpdate: key.onUpdate,
                    onDelete: key.onDelete
                )
            }

            return TableStructureDetails(
                columns: columns,
                primaryKey: primaryKey,
                indexes: indexes,
                uniqueConstraints: uniqueConstraints,
                foreignKeys: foreignKeys,
                dependencies: []
            )
        }
    }

    private func fetchIndexes(schema: String, table: String) async throws -> [SQLiteRawIndex] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).index_list('\(escapeSingleQuotes(table))');"
        let rows = try await connection.query(pragma)

        var collected: [SQLiteRawIndex] = []
        for row in rows {
            guard let indexName = row.column("name")?.string else { continue }
            let isUnique = (row.column("unique")?.integer ?? 0) != 0
            let columns = try await fetchIndexColumns(databaseName: databaseName, indexName: indexName)
            let hasWhereClause = (row.column("partial")?.integer ?? 0) != 0
            let filterCondition = hasWhereClause ? try await fetchIndexWhereClause(databaseName: databaseName, indexName: indexName) : nil
            collected.append(
                SQLiteRawIndex(
                    name: indexName,
                    isUnique: isUnique,
                    columns: columns,
                    filterCondition: filterCondition
                )
            )
        }
        return collected
    }

    private func fetchIndexColumns(databaseName: String, indexName: String) async throws -> [SQLiteRawIndexColumn] {
        let connection = try requireConnection()
        let pragma = "PRAGMA \(databaseName).index_xinfo('\(escapeSingleQuotes(indexName))');"
        let rows = try await connection.query(pragma)

        var columns: [SQLiteRawIndexColumn] = []
        for row in rows {
            let isKey = (row.column("key")?.integer ?? 0) != 0
            guard isKey else { continue }
            let position = row.column("seqno")?.integer ?? 0
            guard let name = row.column("name")?.string else { continue }
            let isAscending = (row.column("desc")?.integer ?? 0) == 0
            columns.append(SQLiteRawIndexColumn(name: name, position: position, isAscending: isAscending))
        }
        return columns.sorted { $0.position < $1.position }
    }

    private func fetchIndexWhereClause(databaseName: String, indexName: String) async throws -> String? {
        let connection = try requireConnection()
        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = 'index' AND name = ?
        LIMIT 1;
        """
        let rows = try await connection.query(sql, [SQLiteData.text(indexName)])
        guard let definition = rows.first?.column("sql")?.string else { return nil }
        if let range = definition.range(of: "WHERE", options: .caseInsensitive) {
            let whereClause = definition[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return whereClause.isEmpty ? nil : whereClause
        }
        return nil
    }

    private func fetchForeignKeys(schema: String, table: String) async throws -> [SQLiteRawForeignKey] {
        let connection = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).foreign_key_list('\(escapeSingleQuotes(table))');"
        let rows = try await connection.query(pragma)

        struct GroupedEntry {
            var table: String
            var columns: [String]
            var references: [String]
            var onUpdate: String?
            var onDelete: String?
        }

        var grouped: [Int: GroupedEntry] = [:]

        for row in rows {
            guard
                let id = row.column("id")?.integer,
                let referencedTable = row.column("table")?.string,
                let fromColumn = row.column("from")?.string,
                let toColumn = row.column("to")?.string
            else { continue }

            let sequence = row.column("seq")?.integer ?? 0
            let onUpdate = row.column("on_update")?.string
            let onDelete = row.column("on_delete")?.string

            var entry = grouped[id] ?? GroupedEntry(table: referencedTable, columns: [], references: [], onUpdate: onUpdate, onDelete: onDelete)

            if entry.columns.count <= sequence {
                entry.columns.append(fromColumn)
            } else {
                entry.columns.insert(fromColumn, at: sequence)
            }

            if entry.references.count <= sequence {
                entry.references.append(toColumn)
            } else {
                entry.references.insert(toColumn, at: sequence)
            }

            if entry.onUpdate == nil {
                entry.onUpdate = onUpdate
            }
            if entry.onDelete == nil {
                entry.onDelete = onDelete
            }

            grouped[id] = entry
        }

        return grouped.keys.sorted().compactMap { key in
            guard let entry = grouped[key] else { return nil }
            return SQLiteRawForeignKey(
                id: key,
                referencedTable: entry.table,
                columns: entry.columns,
                referencedColumns: entry.references,
                onUpdate: entry.onUpdate,
                onDelete: entry.onDelete
            )
        }
    }

    private nonisolated func makeRow(from row: SQLiteRow) -> [String?] {
        row.columns.map { column in
            switch column.data {
            case .integer(let value):
                return String(value)
            case .float(let value):
                return formatDouble(value)
            case .text(let value):
                return value
            case .blob(let buffer):
                return Data(buffer.readableBytesView).base64EncodedString()
            case .null:
                return nil
            }
        }
    }

    private nonisolated func formatDouble(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(format: "%.0f", value)
        } else {
            return String(value)
        }
    }

    private nonisolated func makeColumnInfo(from row: SQLiteRow) -> [ColumnInfo] {
        let columns = row.columns
        guard !columns.isEmpty else { return [] }
        return columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: inferDataType(from: column.data),
                isPrimaryKey: false,
                isNullable: true,
                maxLength: nil
            )
        }
    }

    private nonisolated func inferDataType(from data: SQLiteData) -> String {
        switch data {
        case .integer: return "INTEGER"
        case .float: return "REAL"
        case .text: return "TEXT"
        case .blob: return "BLOB"
        case .null: return "TEXT"
        }
    }

    private nonisolated func resolveColumnsForEmptyResult() -> [ColumnInfo] {
        []
    }

    private func requireConnection() throws -> SQLiteConnection {
        guard let connection else {
            throw DatabaseError.connectionFailed("SQLite connection has been closed")
        }
        return connection
    }

    private func normalizedDatabaseName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty ?? true ? "main" : trimmed!
    }

    private func quoteIdentifier(_ identifier: String) -> String {
        "\"\(identifier.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func escapeSingleQuotes(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }
}

private extension SchemaObjectInfo.ObjectType {
    init?(sqliteType: String) {
        switch sqliteType.lowercased() {
        case "table": self = .table
        case "view": self = .view
        case "trigger": self = .trigger
        default: return nil
        }
    }
}
