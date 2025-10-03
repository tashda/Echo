import Foundation
import Logging
import MySQLNIO
import NIOCore
import NIOPosix
import NIOSSL

struct MySQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mysql")

    func connect(
        host: String,
        port: Int,
        username: String,
        password: String?,
        database: String?,
        tls: Bool
    ) async throws -> DatabaseSession {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let eventLoop = eventLoopGroup.any()
        let address = try SocketAddress.makeAddressResolvingHost(host, port: port)

        let tlsConfiguration = tls ? TLSConfiguration.makeClientConfiguration() : nil

        do {
            let connection = try await MySQLConnection.connect(
                to: address,
                username: username,
                database: database ?? "",
                password: password,
                tlsConfiguration: tlsConfiguration,
                serverHostname: tls ? host : nil,
                logger: logger,
                on: eventLoop
            ).get()

            if let database, !database.isEmpty {
                _ = try await connection.simpleQuery("USE `\(database.replacingOccurrences(of: "`", with: "``"))`").get()
            }

            return MySQLSession(
                connection: connection,
                eventLoopGroup: eventLoopGroup,
                logger: logger,
                defaultDatabase: database
            )
        } catch {
            try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                eventLoopGroup.shutdownGracefully { shutdownError in
                    if let shutdownError {
                        continuation.resume(throwing: shutdownError)
                    } else {
                        continuation.resume()
                    }
                }
            }
            throw DatabaseError.connectionFailed(error.localizedDescription)
        }
    }
}

final class MySQLSession: DatabaseSession {
    private let connection: MySQLConnection
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let logger: Logger
    private let defaultDatabase: String?
    private let formatter = MySQLCellFormatter()

    private let shutdownQueue = DispatchQueue(label: "dk.tippr.echo.mysql.shutdown")
    private var isClosed = false

    init(
        connection: MySQLConnection,
        eventLoopGroup: MultiThreadedEventLoopGroup,
        logger: Logger,
        defaultDatabase: String?
    ) {
        self.connection = connection
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        self.defaultDatabase = defaultDatabase
    }

    deinit {
        if !isClosed {
            Task { await close() }
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true

        do {
            try await connection.close().get()
        } catch {
            logger.warning("Failed to close MySQL connection gracefully: \(error.localizedDescription)")
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            eventLoopGroup.shutdownGracefully(queue: shutdownQueue) { _ in
                continuation.resume()
            }
        }
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        let rows = try await connection.simpleQuery(sql).get()
        let metadata = rows.first?.columnDefinitions ?? []
        let columns = metadata.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.displayName,
                isPrimaryKey: column.flags.contains(.PRIMARY_KEY),
                isNullable: !column.flags.contains(.COLUMN_NOT_NULL),
                maxLength: column.columnLength == 0 ? nil : Int(column.columnLength)
            )
        }

        var results: [[String?]] = []
        results.reserveCapacity(rows.count)

        for row in rows {
            results.append(makeRowValues(row, metadata: metadata))
        }

        if let handler = progressHandler, !columns.isEmpty {
            let update = QueryStreamUpdate(
                columns: columns,
                appendedRows: results,
                totalRowCount: results.count
            )
            handler(update)
        }

        return QueryResultSet(columns: columns.isEmpty ? [ColumnInfo(name: "result", dataType: "text")] : columns, rows: results)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func listSchemas() async throws -> [String] {
        if let current = try await currentDatabaseName() {
            return [current]
        }
        if let defaultDatabase, !defaultDatabase.isEmpty {
            return [defaultDatabase]
        }
        return []
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName: String
        if let schema, !schema.isEmpty {
            schemaName = schema
        } else if let defaultDatabase, !defaultDatabase.isEmpty {
            schemaName = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            schemaName = current
        } else {
            return []
        }

        let sql = """
        SELECT
            table_name,
            table_type
        FROM information_schema.tables
        WHERE table_schema = ?
        ORDER BY table_name;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        return rows.compactMap { row in
            guard
                row.columnDefinitions.count >= 2,
                let name = makeString(row, index: 0),
                let type = makeString(row, index: 1)
            else { return nil }

            guard let objectType = SchemaObjectInfo.ObjectType(mysqlTableType: type) else {
                return nil
            }

            return SchemaObjectInfo(name: name, schema: schemaName, type: objectType)
        }
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema: String
        if let schemaName, !schemaName.isEmpty {
            schema = schemaName
        } else if let defaultDatabase, !defaultDatabase.isEmpty {
            schema = defaultDatabase
        } else if let current = try await currentDatabaseName(), !current.isEmpty {
            schema = current
        } else {
            return []
        }

        let sql = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            column_key,
            character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = ? AND table_name = ?
        ORDER BY ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: tableName)])
        return rows.compactMap { row in
            guard
                let name = makeString(row, index: 0),
                let dataType = makeString(row, index: 1),
                let nullable = makeString(row, index: 2)
            else { return nil }
            let key = makeString(row, index: 3)
            let lengthString = makeString(row, index: 4)
            let maxLength = lengthString.flatMap { Int($0) }
            return ColumnInfo(
                name: name,
                dataType: dataType,
                isPrimaryKey: key == "PRI",
                isNullable: nullable.uppercased() != "NO",
                maxLength: maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        let qualifiedName = "`\(schemaName.replacingOccurrences(of: "`", with: "``"))`.`\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        let sql: String
        switch objectType {
        case .table:
            sql = "SHOW CREATE TABLE \(qualifiedName)"
        case .view:
            sql = "SHOW CREATE VIEW \(qualifiedName)"
        case .materializedView:
            throw DatabaseError.queryError("MySQL does not support materialized views")
        case .function:
            sql = "SHOW CREATE FUNCTION `\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        case .trigger:
            sql = "SHOW CREATE TRIGGER `\(objectName.replacingOccurrences(of: "`", with: "``"))`"
        }

        let rows = try await connection.simpleQuery(sql).get()
        guard let row = rows.first else {
            throw DatabaseError.queryError("Definition not found")
        }

        if let create = row.values.last ?? nil {
            let data = MySQLData(
                type: row.columnDefinitions.last?.columnType ?? .varString,
                format: row.format,
                buffer: create,
                isUnsigned: row.columnDefinitions.last?.flags.contains(.COLUMN_UNSIGNED) ?? false
            )
            return data.string ?? ""
        }

        let combined = row.values.compactMap { buffer -> String? in
            guard let buffer else { return nil }
            var copy = buffer
            return copy.readString(length: copy.readableBytes)
        }
        if let definition = combined.last {
            return definition
        }
        throw DatabaseError.queryError("Unable to decode object definition")
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        var affectedRows: Int = 0
        let future = connection.query(sql, onMetadata: { metadata in
            affectedRows = Int(metadata.affectedRows)
        })
        do {
            _ = try await future.get()
            return affectedRows
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columns = try await getTableSchema(table, schemaName: schema).map { column -> TableStructureDetails.Column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.dataType,
                isNullable: column.isNullable,
                defaultValue: nil,
                generatedExpression: nil
            )
        }

        let primaryKey = try await fetchPrimaryKey(schema: schema, table: table)
        let indexes = try await fetchIndexes(schema: schema, table: table)
        let uniqueConstraints = indexes.filter { $0.isUnique }.map {
            TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns.map(\.name))
        }
        let foreignKeys = try await fetchForeignKeys(schema: schema, table: table)
        let dependencies = try await fetchDependencies(schema: schema, table: table)

        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: uniqueConstraints,
            foreignKeys: foreignKeys,
            dependencies: dependencies
        )
    }

    func listDatabases() async throws -> [String] {
        let rows = try await connection.simpleQuery("SHOW DATABASES").get()
        let excludedSchemas: Set<String> = ["information_schema", "mysql", "performance_schema", "sys"]
        return rows.compactMap { makeString($0, index: 0)?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !excludedSchemas.contains($0.lowercased()) }
    }

    private func makeRowValues(_ row: MySQLRow, metadata: [MySQLProtocol.ColumnDefinition41]) -> [String?] {
        var values: [String?] = []
        values.reserveCapacity(metadata.count)
        for (definition, buffer) in zip(metadata, row.values) {
            let data = MySQLData(
                type: definition.columnType,
                format: row.format,
                buffer: buffer,
                isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)
            )
            values.append(formatter.stringValue(for: data))
        }
        return values
    }

    private func makeString(_ row: MySQLRow, index: Int) -> String? {
        guard row.values.indices.contains(index) else { return nil }
        let definition = row.columnDefinitions[index]
        let data = MySQLData(
            type: definition.columnType,
            format: row.format,
            buffer: row.values[index],
            isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)
        )
        return formatter.stringValue(for: data)
    }

    private func currentDatabaseName() async throws -> String? {
        let rows = try await connection.simpleQuery("SELECT DATABASE()").get()
        guard let row = rows.first, let value = makeString(row, index: 0) else { return nil }
        return value.isEmpty ? nil : value
    }

    private func performQuery(_ sql: String, binds: [MySQLData] = []) async throws -> ([MySQLRow], MySQLQueryMetadata?) {
        let renderedSQL: String
        if binds.isEmpty {
            renderedSQL = sql
        } else {
            renderedSQL = try renderSQL(sql, with: binds)
        }

        let rows = try await connection.simpleQuery(renderedSQL).get()
        return (rows, nil)
    }

    private func renderSQL(_ sql: String, with binds: [MySQLData]) throws -> String {
        var result = String()
        result.reserveCapacity(sql.count + binds.count * 8)

        enum QuoteContext {
            case none
            case single
            case double
            case backtick
        }

        var context: QuoteContext = .none
        var bindIndex = 0
        var index = sql.startIndex

        while index < sql.endIndex {
            let character = sql[index]

            switch context {
            case .none:
                switch character {
                case "'":
                    context = .single
                    result.append(character)
                case "\"":
                    context = .double
                    result.append(character)
                case "`":
                    context = .backtick
                    result.append(character)
                case "?":
                    guard bindIndex < binds.count else {
                        throw DatabaseError.queryError("Missing bind value for placeholder in SQL: \(sql)")
                    }
                    result.append(try renderLiteral(from: binds[bindIndex]))
                    bindIndex += 1
                default:
                    result.append(character)
                }
            case .single:
                result.append(character)
                if character == "'" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "'" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            case .double:
                result.append(character)
                if character == "\"" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "\"" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            case .backtick:
                result.append(character)
                if character == "`" {
                    let next = sql.index(after: index)
                    if next < sql.endIndex, sql[next] == "`" {
                        index = next
                        result.append(sql[index])
                    } else {
                        context = .none
                    }
                }
            }

            index = sql.index(after: index)
        }

        guard bindIndex == binds.count else {
            throw DatabaseError.queryError("Too many bind values provided for SQL: \(sql)")
        }

        return result
    }

    private func renderLiteral(from data: MySQLData) throws -> String {
        if data.type == .null || data.buffer == nil {
            return "NULL"
        }

        if let string = data.string {
            return "'\(escapeStringLiteral(string))'"
        }

        if let int = data.int {
            return String(int)
        }

        if let double = data.double {
            return String(double)
        }

        if let bool = data.bool {
            return bool ? "1" : "0"
        }

        throw DatabaseError.queryError("Unsupported bind parameter type for MySQL query: \(data)")
    }

    private func escapeStringLiteral(_ value: String) -> String {
        var escaped = String()
        escaped.reserveCapacity(value.count)

        for character in value {
            switch character {
            case "'":
                escaped.append("''")
            case "\\":
                escaped.append("\\\\")
            default:
                escaped.append(character)
            }
        }

        return escaped
    }

    private func fetchPrimaryKey(schema: String, table: String) async throws -> TableStructureDetails.PrimaryKey? {
        let sql = """
        SELECT k.constraint_name, k.column_name
        FROM information_schema.table_constraints t
        JOIN information_schema.key_column_usage k
          ON k.constraint_name = t.constraint_name
         AND k.table_schema = t.table_schema
        WHERE t.table_schema = ?
          AND t.table_name = ?
          AND t.constraint_type = 'PRIMARY KEY'
        ORDER BY k.ordinal_position;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        guard !rows.isEmpty else { return nil }
        let name = makeString(rows.first!, index: 0) ?? "PRIMARY"
        let columns = rows.compactMap { makeString($0, index: 1) }
        return TableStructureDetails.PrimaryKey(name: name, columns: columns)
    }

    private func fetchIndexes(schema: String, table: String) async throws -> [TableStructureDetails.Index] {
        let sql = """
        SELECT
            index_name,
            non_unique,
            seq_in_index,
            column_name,
            collation
        FROM information_schema.statistics
        WHERE table_schema = ? AND table_name = ?
        ORDER BY index_name, seq_in_index;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])

        var grouped: [String: (isUnique: Bool, columns: [TableStructureDetails.Index.Column], filter: String?)] = [:]
        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let isUnique = (makeString(row, index: 1) ?? "1") == "0"
            let position = Int(makeString(row, index: 2) ?? "0") ?? 0
            guard let columnName = makeString(row, index: 3) else { continue }
            let collation = makeString(row, index: 4)
            let sortOrder: TableStructureDetails.Index.Column.SortOrder = collation == "D" ? .descending : .ascending
            var entry = grouped[name] ?? (isUnique, [], nil)
            entry.isUnique = entry.isUnique && isUnique
            entry.columns.append(TableStructureDetails.Index.Column(name: columnName, position: position, sortOrder: sortOrder))
            grouped[name] = entry
        }

        return grouped.compactMap { name, value in
            guard name.uppercased() != "PRIMARY" else { return nil }
            let sortedColumns = value.columns.sorted { $0.position < $1.position }
            return TableStructureDetails.Index(
                name: name,
                columns: sortedColumns,
                isUnique: value.isUnique,
                filterCondition: value.filter
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchForeignKeys(schema: String, table: String) async throws -> [TableStructureDetails.ForeignKey] {
        let sql = """
        SELECT
            rc.constraint_name,
            kcu.column_name,
            kcu.referenced_table_schema,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule,
            kcu.ordinal_position
        FROM information_schema.referential_constraints rc
        JOIN information_schema.key_column_usage kcu
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE rc.constraint_schema = ?
          AND rc.table_name = ?
        ORDER BY rc.constraint_name, kcu.ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        var grouped: [String: (columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?)] = [:]

        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let column = makeString(row, index: 1)
            let refSchema = makeString(row, index: 2) ?? schema
            let refTable = makeString(row, index: 3) ?? ""
            let refColumn = makeString(row, index: 4)
            let onUpdate = makeString(row, index: 5)
            let onDelete = makeString(row, index: 6)

            var entry = grouped[name] ?? ([], refSchema, refTable, [], onUpdate, onDelete)
            if let column { entry.columns.append(column) }
            if let refColumn { entry.referencedColumns.append(refColumn) }
            entry.onUpdate = onUpdate
            entry.onDelete = onDelete
            grouped[name] = entry
        }

        return grouped.map { name, value in
            TableStructureDetails.ForeignKey(
                name: name,
                columns: value.columns,
                referencedSchema: value.referencedSchema,
                referencedTable: value.referencedTable,
                referencedColumns: value.referencedColumns,
                onUpdate: value.onUpdate,
                onDelete: value.onDelete
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchDependencies(schema: String, table: String) async throws -> [TableStructureDetails.Dependency] {
        let sql = """
        SELECT
            kcu.constraint_name,
            kcu.column_name,
            kcu.referenced_table_name,
            kcu.referenced_column_name,
            rc.update_rule,
            rc.delete_rule
        FROM information_schema.key_column_usage kcu
        JOIN information_schema.referential_constraints rc
          ON rc.constraint_name = kcu.constraint_name
         AND rc.constraint_schema = kcu.constraint_schema
        WHERE kcu.referenced_table_schema = ?
          AND kcu.referenced_table_name = ?
        ORDER BY kcu.constraint_name, kcu.ordinal_position;
        """

        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schema), MySQLData(string: table)])
        var grouped: [String: TableStructureDetails.Dependency] = [:]

        for row in rows {
            guard let name = makeString(row, index: 0) else { continue }
            let column = makeString(row, index: 1)
            let baseTable = makeString(row, index: 2)
            let refColumn = makeString(row, index: 3)
            let onUpdate = makeString(row, index: 4)
            let onDelete = makeString(row, index: 5)

            var dependency = grouped[name] ?? TableStructureDetails.Dependency(
                name: name,
                baseColumns: [],
                referencedTable: baseTable ?? "",
                referencedColumns: [],
                onUpdate: onUpdate,
                onDelete: onDelete
            )

            if let column { dependency.baseColumns.append(column) }
            if let refColumn { dependency.referencedColumns.append(refColumn) }
            dependency.onUpdate = onUpdate
            dependency.onDelete = onDelete
            grouped[name] = dependency
        }

        return Array(grouped.values).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

extension MySQLSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let tableSQL = """
        SELECT
            t.table_name,
            t.table_type,
            c.column_name,
            c.data_type,
            c.is_nullable,
            c.column_key,
            c.character_maximum_length,
            c.ordinal_position
        FROM information_schema.tables t
        LEFT JOIN information_schema.columns c
          ON c.table_schema = t.table_schema
         AND c.table_name = t.table_name
        WHERE t.table_schema = ? AND t.table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY t.table_name, c.ordinal_position;
        """

        let (rows, _) = try await performQuery(tableSQL, binds: [MySQLData(string: schemaName)])

        var grouped: [String: SchemaObjectAccumulator] = [:]
        for row in rows {
            guard
                let name = makeString(row, index: 0),
                let type = makeString(row, index: 1)
            else { continue }

            let objectType = SchemaObjectInfo.ObjectType(mysqlTableType: type) ?? .table
            var accumulator = grouped[name] ?? SchemaObjectAccumulator(type: objectType)
            if let columnName = makeString(row, index: 2) {
                let dataType = makeString(row, index: 3) ?? ""
                let nullable = makeString(row, index: 4)
                let columnKey = makeString(row, index: 5)
                let length = makeString(row, index: 6)
                let column = ColumnInfo(
                    name: columnName,
                    dataType: dataType,
                    isPrimaryKey: columnKey == "PRI",
                    isNullable: (nullable ?? "YES").uppercased() != "NO",
                    maxLength: length.flatMap { Int($0) }
                )
                accumulator.columns.append(column)
            }
            grouped[name] = accumulator
        }

        if let progress {
            let orderedNames = grouped.keys.sorted()
            for (index, name) in orderedNames.enumerated() {
                if let type = grouped[name]?.type {
                    await progress(type, index + 1, orderedNames.count)
                }
            }
        }

        let tables: [SchemaObjectInfo] = grouped.map { name, accumulator in
            SchemaObjectInfo(
                name: name,
                schema: schemaName,
                type: accumulator.type,
                columns: accumulator.columns
            )
        }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let functions = try await loadRoutineObjects(schemaName: schemaName, progress: progress)
        let triggers = try await loadTriggerObjects(schemaName: schemaName, progress: progress)

        let objects = tables + functions + triggers
        return SchemaInfo(name: schemaName, objects: objects)
    }

    private func loadRoutineObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let sql = """
        SELECT routine_name, routine_type
        FROM information_schema.routines
        WHERE routine_schema = ?
        ORDER BY routine_name;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        if let progress {
            for (index, row) in rows.enumerated() {
                if let kind = makeString(row, index: 1), let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: kind) {
                    await progress(type, index + 1, rows.count)
                }
            }
        }
        return rows.compactMap { row in
            guard
                let name = makeString(row, index: 0),
                let routineType = makeString(row, index: 1),
                let type = SchemaObjectInfo.ObjectType(mysqlRoutineType: routineType)
            else { return nil }
            return SchemaObjectInfo(name: name, schema: schemaName, type: type)
        }
    }

    private func loadTriggerObjects(
        schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> [SchemaObjectInfo] {
        let sql = """
        SELECT trigger_name, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = ?
        ORDER BY trigger_name;
        """
        let (rows, _) = try await performQuery(sql, binds: [MySQLData(string: schemaName)])
        if let progress {
            for (index, _) in rows.enumerated() {
                await progress(.trigger, index + 1, rows.count)
            }
        }
        return rows.compactMap { row in
            guard let name = makeString(row, index: 0) else { return nil }
            let action = makeString(row, index: 1)
            let table = makeString(row, index: 2)
            return SchemaObjectInfo(name: name, schema: schemaName, type: .trigger, columns: [], triggerAction: action, triggerTable: table)
        }
    }

    private struct SchemaObjectAccumulator {
        let type: SchemaObjectInfo.ObjectType
        var columns: [ColumnInfo] = []
    }
}

private extension SchemaObjectInfo.ObjectType {
    init?(mysqlTableType: String) {
        switch mysqlTableType.uppercased() {
        case "BASE TABLE": self = .table
        case "VIEW": self = .view
        default: return nil
        }
    }

    init?(mysqlRoutineType: String) {
        switch mysqlRoutineType.uppercased() {
        case "FUNCTION": self = .function
        default: return nil
        }
    }
}

private extension MySQLProtocol.ColumnDefinition41 {
    var displayName: String {
        let name = self.columnType.name
        if name.uppercased().hasPrefix("MYSQL_TYPE_") {
            return String(name.dropFirst("MYSQL_TYPE_".count)).lowercased()
        }
        return name.lowercased()
    }
}

private struct MySQLCellFormatter {
    private let dateFormatter: DateFormatter
    private let dateTimeFormatter: ISO8601DateFormatter
    private let timeFormatter: DateFormatter

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = dateFormatter

        let dateTimeFormatter = ISO8601DateFormatter()
        dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        dateTimeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.dateTimeFormatter = dateTimeFormatter

        let timeFormatter = DateFormatter()
        timeFormatter.calendar = Calendar(identifier: .gregorian)
        timeFormatter.locale = Locale(identifier: "en_US_POSIX")
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        timeFormatter.dateFormat = "HH:mm:ss"
        self.timeFormatter = timeFormatter
    }

    func stringValue(for data: MySQLData) -> String? {
        guard data.buffer != nil else { return nil }

        switch data.type {
        case .null:
            return nil
        case .tiny, .short, .long, .longlong, .int24, .bit, .year:
            if let int = data.int64 { return String(int) }
            if let uint = data.uint64 { return String(uint) }
        case .float:
            if let value = data.float { return formatFloatingPoint(Double(value)) }
        case .double:
            if let value = data.double { return formatFloatingPoint(value) }
        case .decimal, .newdecimal:
            return data.string
        case .timestamp, .timestamp2, .datetime, .datetime2:
            if let date = data.date { return dateTimeFormatter.string(from: date) }
        case .date, .newdate:
            if let date = data.date { return dateFormatter.string(from: date) }
        case .time, .time2:
            if let time = data.time { return string(from: time) }
        case .json:
            return data.string
        case .blob, .longBlob, .mediumBlob, .tinyBlob, .geometry:
            return data.buffer.flatMap { hexString(from: $0) }
        case .varchar, .varString, .string, .enum, .set:
            return data.string
        default:
            break
        }

        if let string = data.string {
            return string
        }

        if let buffer = data.buffer {
            return hexString(from: buffer)
        }

        return nil
    }

    private func string(from time: MySQLTime) -> String? {
        guard let date = time.date else {
            guard
                let hour = time.hour,
                let minute = time.minute,
                let second = time.second
            else { return nil }
            let fractional = time.microsecond ?? 0
            let base = String(format: "%02d:%02d:%02d", hour, minute, second)
            if fractional == 0 { return base }
            var fractionalString = String(format: "%06d", fractional)
            while fractionalString.last == "0" { fractionalString.removeLast() }
            return base + "." + fractionalString
        }
        return timeFormatter.string(from: date)
    }

    private func formatFloatingPoint(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value > 0 ? "Infinity" : "-Infinity" }
        let absValue = abs(value)
        if (absValue >= 1e-4 && absValue < 1e6) || value == 0 {
            return String(format: "%.15g", value)
        }
        return String(value)
    }

    private func hexString(from buffer: ByteBuffer) -> String {
        var copy = buffer
        guard let bytes = copy.readBytes(length: copy.readableBytes) else { return "0x" }
        return bytes.reduce(into: "0x") { partial, byte in
            partial.append(String(format: "%02X", byte))
        }
    }
}
