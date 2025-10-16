import Foundation
import SQLite
import SQLite3

struct SQLiteFactory: DatabaseFactory {
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
            let connection = try Connection(resolvedPath)
            let session = SQLiteSession()
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

private struct SQLiteSchemaObjectRecord: Sendable {
    let name: String
    let type: String
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
    private var connectionRef: Unmanaged<Connection>?

    init() {}

    func bootstrap(with connection: Connection) {
        connectionRef?.release()
        connectionRef = Unmanaged.passRetained(connection)
    }

    func close() async {
        connectionRef?.release()
        connectionRef = nil
    }

    deinit {
        connectionRef?.release()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        let conn = try requireConnection()

        var rawColumns: [SQLiteRawColumn] = []
        var resolvedColumns: [ColumnInfo] = []
        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(4_096)
        var totalRowCount = 0

        var pendingPreviewRows: [[String?]] = []
        pendingPreviewRows.reserveCapacity(256)
        var pendingEncodedRows: [ResultBinaryRow] = []
        pendingEncodedRows.reserveCapacity(256)
        let operationStart = CFAbsoluteTimeGetCurrent()
        var lastFlushTimestamp = operationStart
        var batchDecodeDuration: TimeInterval = 0
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.05

        let flush: (_ force: Bool) -> Void = { force in
            guard !pendingEncodedRows.isEmpty else { return }

            if !force, progressHandler != nil, !resolvedColumns.isEmpty {
                let threshold: Int
                switch totalRowCount {
                case 0..<1024:
                    threshold = 128
                case 1024..<4096:
                    threshold = 512
                case 4096..<16_384:
                    threshold = 512
                default:
                    threshold = 1024
                }
                let shouldFlushByCount = pendingEncodedRows.count >= threshold
                if !shouldFlushByCount {
                    let elapsed = CFAbsoluteTimeGetCurrent() - lastFlushTimestamp
                    guard elapsed >= maxFlushLatency else { return }
                }
            }

            let previewBatch = pendingPreviewRows
            let encodedBatch = pendingEncodedRows
            pendingPreviewRows.removeAll(keepingCapacity: true)
            pendingEncodedRows.removeAll(keepingCapacity: true)
            let now = CFAbsoluteTimeGetCurrent()
            let metrics = QueryStreamMetrics(
                batchRowCount: encodedBatch.count,
                loopElapsed: now - lastFlushTimestamp,
                decodeDuration: batchDecodeDuration,
                totalElapsed: now - operationStart,
                cumulativeRowCount: totalRowCount
            )
            lastFlushTimestamp = now
            batchDecodeDuration = 0

            guard let handler = progressHandler, !resolvedColumns.isEmpty else { return }
            let update = QueryStreamUpdate(
                columns: resolvedColumns,
                appendedRows: previewBatch,
                encodedRows: encodedBatch,
                totalRowCount: totalRowCount,
                metrics: metrics
            )
            handler(update)
        }

        try withSQLiteStatement(connection: conn, sql: sql) { statement in
            let columnCount = Int(sqlite3_column_count(statement))
            if rawColumns.isEmpty {
                rawColumns.reserveCapacity(columnCount)
                for index in 0..<columnCount {
                    let name = sqlite3_column_name(statement, Int32(index)).flatMap { String(cString: $0) } ?? "column\(index + 1)"
                    let declaredType = sqlite3_column_decltype(statement, Int32(index)).flatMap { String(cString: $0) }
                    rawColumns.append(
                        SQLiteRawColumn(
                            name: name,
                            dataType: declaredType?.uppercased() ?? "TEXT",
                            isPrimaryKey: false,
                            isNullable: true,
                            maxLength: nil
                        )
                    )
                }
                resolvedColumns = rawColumns.map { column in
                    ColumnInfo(
                        name: column.name,
                        dataType: column.dataType,
                        isPrimaryKey: column.isPrimaryKey,
                        isNullable: column.isNullable,
                        maxLength: column.maxLength
                    )
                }
            }

            while true {
                let stepResult = sqlite3_step(statement)
                switch stepResult {
                case SQLITE_ROW:
                    let decodeStart = CFAbsoluteTimeGetCurrent()
                    let rowValues = try makeRow(statement: statement, columnCount: columnCount)
                    batchDecodeDuration += CFAbsoluteTimeGetCurrent() - decodeStart
                    let encoded = ResultBinaryRowCodec.encode(row: rowValues)
                    pendingEncodedRows.append(encoded)
                    totalRowCount += 1
                    if totalRowCount <= streamingPreviewLimit {
                        pendingPreviewRows.append(rowValues)
                    }
                    if previewRows.count < 4_096 {
                        previewRows.append(rowValues)
                    }
                    flush(false)
                case SQLITE_DONE:
                    return
                default:
                    throw DatabaseError.queryError(String(cString: sqlite3_errmsg(conn.handle)))
                }
            }
        }

        flush(true)

        if resolvedColumns.isEmpty {
            resolvedColumns = rawColumns.map { column in
                ColumnInfo(
                    name: column.name,
                    dataType: column.dataType,
                    isPrimaryKey: column.isPrimaryKey,
                    isNullable: column.isNullable,
                    maxLength: column.maxLength
                )
            }
        }

        if resolvedColumns.isEmpty {
            resolvedColumns = [ColumnInfo(name: "result", dataType: "TEXT")]
        }

        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let conn = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let sql = """
        SELECT name, type
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type IN ('table', 'view')
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name;
        """

        let records = try withSQLiteStatement(connection: conn, sql: sql) { statement in
            var objects: [SQLiteSchemaObjectRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let namePtr = sqlite3_column_text(statement, 0),
                    let typePtr = sqlite3_column_text(statement, 1)
                else { continue }
                let name = String(cString: namePtr)
                let typeString = String(cString: typePtr)
                objects.append(SQLiteSchemaObjectRecord(name: name, type: typeString))
            }
            return objects
        }

        return await MainActor.run {
            records.compactMap { record in
                guard let objectType = SchemaObjectInfo.ObjectType(sqliteType: record.type) else { return nil }
                return SchemaObjectInfo(name: record.name, schema: databaseName, type: objectType)
            }
        }
    }

    func listDatabases() async throws -> [String] {
        let conn = try requireConnection()
        let sql = "PRAGMA database_list;"
        return try withSQLiteStatement(connection: conn, sql: sql) { statement in
            var names: [String] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let namePtr = sqlite3_column_text(statement, 1) else { continue }
                let name = String(cString: namePtr)
                names.append(name)
            }
            return names.isEmpty ? [normalizedDatabaseName(nil)] : names
        }
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
        let conn = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let pragma = "PRAGMA \(databaseName).table_info('\(escapeSingleQuotes(tableName))');"
        let rawColumns = try withSQLiteStatement(connection: conn, sql: pragma) { statement in
            var columns: [SQLiteRawColumn] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let namePtr = sqlite3_column_text(statement, 1) else { continue }
                let name = String(cString: namePtr)
                let typePtr = sqlite3_column_text(statement, 2)
                let type = typePtr.map { String(cString: $0) } ?? ""
                let notNull = sqlite3_column_int(statement, 3) != 0
                let pk = sqlite3_column_int(statement, 5) != 0
                columns.append(
                    SQLiteRawColumn(
                        name: name,
                        dataType: type.isEmpty ? "TEXT" : type,
                        isPrimaryKey: pk,
                        isNullable: !notNull,
                        maxLength: nil
                    )
                )
            }
            return columns
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

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        let conn = try requireConnection()
        let databaseName = normalizedDatabaseName(schemaName)
        let typeString: String
        switch objectType {
        case .table: typeString = "table"
        case .view: typeString = "view"
        case .trigger: typeString = "trigger"
        case .materializedView, .function:
            throw DatabaseError.queryError("SQLite does not support definitions for \(objectType.rawValue)")
        }
        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = '\(typeString)'
          AND name = ?
        LIMIT 1;
        """

        return try withSQLiteStatement(connection: conn, sql: sql) { statement in
            try bindText(statement, index: 1, value: objectName, connection: conn)
            while true {
                let step = sqlite3_step(statement)
                if step == SQLITE_ROW {
                    if let sqlPtr = sqlite3_column_text(statement, 0) {
                        return String(cString: sqlPtr)
                    }
                    return ""
                } else if step == SQLITE_DONE {
                    throw DatabaseError.queryError("Definition for \(objectName) was not found")
                } else {
                    throw DatabaseError.queryError(String(cString: sqlite3_errmsg(conn.handle)))
                }
            }
        }
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let conn = try requireConnection()
        do {
            try conn.execute(sql)
            return conn.changes
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columnsInfo = try await getTableSchema(table, schemaName: schema)
        let rawIndexes = try fetchIndexes(schema: schema, table: table)
        let rawForeignKeys = try fetchForeignKeys(schema: schema, table: table)
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
            let primaryKey = primaryKeyColumns.isEmpty ? nil : TableStructureDetails.PrimaryKey(name: "primary_key", columns: primaryKeyColumns)

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

    private func fetchIndexes(schema: String, table: String) throws -> [SQLiteRawIndex] {
        let conn = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).index_list('\(escapeSingleQuotes(table))');"
        return try withSQLiteStatement(connection: conn, sql: pragma) { statement in
            var collected: [SQLiteRawIndex] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard
                    let namePtr = sqlite3_column_text(statement, 1)
                else { continue }
                let indexName = String(cString: namePtr)
                let isUnique = sqlite3_column_int(statement, 2) != 0
                let columns = try fetchIndexColumns(databaseName: databaseName, indexName: indexName)
                let filterCondition = sqlite3_column_int(statement, 4) != 0 ? fetchIndexWhereClause(databaseName: databaseName, indexName: indexName) : nil
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
    }

    private func fetchIndexColumns(databaseName: String, indexName: String) throws -> [SQLiteRawIndexColumn] {
        let conn = try requireConnection()
        let pragma = "PRAGMA \(databaseName).index_xinfo('\(escapeSingleQuotes(indexName))');"
        return try withSQLiteStatement(connection: conn, sql: pragma) { statement in
            var columns: [SQLiteRawIndexColumn] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let isKey = sqlite3_column_int(statement, 5) != 0
                guard isKey else { continue }
                let position = Int(sqlite3_column_int(statement, 0))
                guard let namePtr = sqlite3_column_text(statement, 2) else { continue }
                let name = String(cString: namePtr)
                let isAscending = sqlite3_column_int(statement, 3) == 0
                columns.append(SQLiteRawIndexColumn(name: name, position: position, isAscending: isAscending))
            }
            return columns.sorted { $0.position < $1.position }
        }
    }

    private func fetchIndexWhereClause(databaseName: String, indexName: String) -> String? {
        guard let connectionRef else { return nil }
        let conn = connectionRef.takeUnretainedValue()
        let sql = """
        SELECT sql
        FROM \(quoteIdentifier(databaseName)).sqlite_master
        WHERE type = 'index' AND name = ?
        LIMIT 1;
        """

        return try? withSQLiteStatement(connection: conn, sql: sql) { statement in
            try bindText(statement, index: 1, value: indexName, connection: conn)
            if sqlite3_step(statement) == SQLITE_ROW, let ptr = sqlite3_column_text(statement, 0) {
                let definition = String(cString: ptr)
                if let range = definition.range(of: "WHERE", options: .caseInsensitive) {
                    let whereClause = definition[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
                    return whereClause.isEmpty ? nil : whereClause
                }
            }
            return nil
        }
    }

    private func fetchForeignKeys(schema: String, table: String) throws -> [SQLiteRawForeignKey] {
        let conn = try requireConnection()
        let databaseName = normalizedDatabaseName(schema)
        let pragma = "PRAGMA \(databaseName).foreign_key_list('\(escapeSingleQuotes(table))');"
        return try withSQLiteStatement(connection: conn, sql: pragma) { statement in
            var grouped: [Int: (table: String, columns: [String], references: [String], onUpdate: String?, onDelete: String?)] = [:]
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(statement, 0))
                guard let foreignTablePtr = sqlite3_column_text(statement, 2) else { continue }
                let foreignTable = String(cString: foreignTablePtr)
                let fromColumn = sqlite3_column_text(statement, 3).map { String(cString: $0) } ?? ""
                let toColumn = sqlite3_column_text(statement, 4).map { String(cString: $0) } ?? ""
                let onUpdate = sqlite3_column_text(statement, 5).map { String(cString: $0) }
                let onDelete = sqlite3_column_text(statement, 6).map { String(cString: $0) }

                if grouped[id] == nil {
                    grouped[id] = (table: foreignTable, columns: [], references: [], onUpdate: onUpdate, onDelete: onDelete)
                }
                grouped[id]?.columns.append(fromColumn)
                grouped[id]?.references.append(toColumn)
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
    }

    private func makeRow(statement: OpaquePointer?, columnCount: Int) throws -> [String?] {
        var row: [String?] = []
        row.reserveCapacity(columnCount)
        for index in 0..<columnCount {
            let type = sqlite3_column_type(statement, Int32(index))
            switch type {
            case SQLITE_INTEGER:
                let value = sqlite3_column_int64(statement, Int32(index))
                row.append(String(value))
            case SQLITE_FLOAT:
                let value = sqlite3_column_double(statement, Int32(index))
                row.append(formatDouble(value))
            case SQLITE_TEXT:
                if let textPtr = sqlite3_column_text(statement, Int32(index)) {
                    row.append(String(cString: textPtr))
                } else {
                    row.append(nil)
                }
            case SQLITE_BLOB:
                if let bytes = sqlite3_column_blob(statement, Int32(index)) {
                    let length = Int(sqlite3_column_bytes(statement, Int32(index)))
                    let data = Data(bytes: bytes, count: length)
                    row.append(data.base64EncodedString())
                } else {
                    row.append("")
                }
            case SQLITE_NULL:
                row.append(nil)
            default:
                row.append(nil)
            }
        }
        return row
    }

    private func formatDouble(_ value: Double) -> String {
        if value.rounded(.towardZero) == value {
            return String(format: "%.0f", value)
        } else {
            return String(value)
        }
    }

    private func requireConnection() throws -> Connection {
        guard let connectionRef else {
            throw DatabaseError.connectionFailed("SQLite connection has been closed")
        }
        return connectionRef.takeUnretainedValue()
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

    private func withSQLiteStatement<T>(connection: Connection, sql: String, _ body: (OpaquePointer?) throws -> T) throws -> T {
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(connection.handle, sql, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let message = String(cString: sqlite3_errmsg(connection.handle))
            sqlite3_finalize(statement)
            throw DatabaseError.queryError(message)
        }
        defer { sqlite3_finalize(statement) }
        return try body(statement)
    }

    private func bindText(_ statement: OpaquePointer?, index: Int32, value: String, connection: Connection) throws {
        let destructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let result = value.withCString { cString in
            sqlite3_bind_text(statement, index, cString, -1, destructor)
        }
        guard result == SQLITE_OK else {
            throw DatabaseError.queryError(String(cString: sqlite3_errmsg(connection.handle)))
        }
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
