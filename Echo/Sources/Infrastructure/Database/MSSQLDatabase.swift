import Foundation
import Logging
import NIOCore
import NIOPosix
import NIOSSL
import Network
@preconcurrency import TDS

struct MSSQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mssql")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let eventLoop = eventLoopGroup.any()

        do {
            let address = try SocketAddress.makeAddressResolvingHost(host, port: port)
            let tlsConfiguration = tls ? TLSConfiguration.makeClientConfiguration() : nil
            let hostnameForTLS = (tls && MSSQLNIOFactory.shouldSendSNI(host: host)) ? host : nil

            let connection = try await TDSConnection.connect(
                to: address,
                tlsConfiguration: tlsConfiguration,
                serverHostname: hostnameForTLS,
                on: eventLoop
            ).get()

            let databaseName = database ?? ""

            switch authentication.method {
            case .sqlPassword:
                guard let password = authentication.password else {
                    throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
                }
                try await connection
                    .login(
                        username: authentication.username,
                        password: password,
                        server: host,
                        database: databaseName
                    )
                    .get()
            case .windowsIntegrated:
                throw DatabaseError.authenticationFailed(
                    "Windows integrated authentication is not supported by the current SQL Server driver"
                )
            }

            return MSSQLSession(
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

extension MSSQLNIOFactory {
    private static func shouldSendSNI(host: String) -> Bool {
        if IPv4Address(host) != nil { return false }
        if IPv6Address(host) != nil { return false }
        return true
    }
}

final class MSSQLSession: DatabaseSession {
    private let connection: TDSConnection
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let logger: Logger
    private let defaultDatabase: String?
    private let formatter = MSSQLCellFormatter()

    private let shutdownQueue = DispatchQueue(label: "dk.tippr.echo.mssql.shutdown")
    private var isClosed = false

    init(
        connection: TDSConnection,
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
        guard !isClosed else { return }
        isClosed = true

        let connection = self.connection
        let eventLoopGroup = self.eventLoopGroup
        let shutdownQueue = self.shutdownQueue
        let logger = self.logger

        connection.close().whenComplete { result in
            if case .failure(let error) = result {
                logger.warning("Failed to close MSSQL connection during deinit: \(error.localizedDescription)")
            }

            eventLoopGroup.shutdownGracefully(queue: shutdownQueue) { shutdownError in
                if let shutdownError {
                    logger.warning("Failed to shut down MSSQL event loop group during deinit: \(shutdownError.localizedDescription)")
                }
            }
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true

        do {
            try await connection.close().get()
        } catch {
            logger.warning("Failed to close MSSQL connection gracefully: \(error.localizedDescription)")
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
        var resolvedColumns = (try? await describeColumns(for: sql)) ?? []
        var shouldDropRowNumberColumn = false

        if let first = resolvedColumns.first, first.name == "__rownum" {
            resolvedColumns.removeFirst()
            shouldDropRowNumberColumn = true
        }

        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        var encounteredError: Error?
        var wasCancelled = false

        var worker: ResultStreamBatchWorker?

        let future = connection.rawSql(sql, onRow: { rawRow in
            if Task.isCancelled {
                wasCancelled = true
                throw CancellationError()
            }

            let wrappedRow = MSSQLRow(row: rawRow, formatter: self.formatter)

            if resolvedColumns.isEmpty {
                resolvedColumns = self.makeColumnInfo(from: wrappedRow)
                if let first = resolvedColumns.first, first.name == "__rownum" {
                    resolvedColumns.removeFirst()
                    shouldDropRowNumberColumn = true
                }
            }

            guard !resolvedColumns.isEmpty else { return }

            if worker == nil, let handler = progressHandler, !resolvedColumns.isEmpty {
                worker = ResultStreamBatchWorker(
                    label: "dk.tippr.echo.mssql.streamWorker",
                    columns: resolvedColumns,
                    streamingPreviewLimit: streamingPreviewLimit,
                    maxFlushLatency: maxFlushLatency,
                    operationStart: operationStart,
                    progressHandler: handler
                )
            }

            let decodeStart = CFAbsoluteTimeGetCurrent()
            var formatted = self.formatRow(wrappedRow, columns: resolvedColumns)
            if shouldDropRowNumberColumn, formatted.count > resolvedColumns.count {
                formatted.removeFirst()
            }
            let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart
            let finalRow = formatted
            totalRowCount += 1
            if previewRows.count < streamingPreviewLimit {
                previewRows.append(finalRow)
            }

            let previewForWorker: [String?]? = totalRowCount <= streamingPreviewLimit ? finalRow : nil
            let encodedRow = ResultBinaryRowCodec.encode(row: finalRow)

            worker?.enqueue(
                .init(
                    previewValues: previewForWorker,
                    storage: .encoded(encodedRow),
                    totalRowCount: totalRowCount,
                    decodeDuration: decodeDuration
                )
            )
        })

        do {
            try await future.get()
        } catch is CancellationError {
            encounteredError = CancellationError()
        } catch {
            encounteredError = error
        }

        worker?.finish(totalRowCount: totalRowCount)

        if wasCancelled || encounteredError is CancellationError {
            throw CancellationError()
        }

        if let error = encounteredError {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        if resolvedColumns.isEmpty {
            if let firstRow = previewRows.first {
                resolvedColumns = firstRow.enumerated().map { index, _ in
                    ColumnInfo(name: "column\(index + 1)", dataType: "text")
                }
            } else {
                resolvedColumns = [ColumnInfo(name: "result", dataType: "text")]
            }
        }

        return QueryResultSet(columns: resolvedColumns, rows: previewRows, totalRowCount: totalRowCount)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema?.isEmpty == false ? schema! : "dbo"
        let escapedSchema = MSSQLSession.escapeLiteral(schemaName)
        let sql = """
        SELECT
            table_name,
            table_type
        FROM information_schema.tables
        WHERE table_schema = '\(escapedSchema)'
        ORDER BY table_name;
        """

        let rows = try await fetchRows(sql)
        let columnMap = try await fetchColumnsByObject(schemaName: schemaName)

        return rows.compactMap { row -> SchemaObjectInfo? in
            guard let name = row.string("table_name"), let rawType = row.string("table_type") else { return nil }
            let type: SchemaObjectInfo.ObjectType
            switch rawType.uppercased() {
            case "BASE TABLE": type = .table
            case "VIEW": type = .view
            default: type = .table
            }
            let columns = columnMap[name] ?? []
            return SchemaObjectInfo(name: name, schema: schemaName, type: type, columns: columns)
        }
    }

    func listDatabases() async throws -> [String] {
        logger.debug("Listing MSSQL databases: starting enumeration")

        let currentName = await resolvedCurrentDatabase()

        func cleaned(_ names: [String], includeSystem: Bool = false) -> Set<String> {
            var result = Set<String>()
            for name in names where !name.isEmpty {
                let lower = name.lowercased()
                let isSystem = ["master", "tempdb", "model", "msdb"].contains(lower)
                if isSystem {
                    if includeSystem {
                        result.insert(name)
                    }
                    continue
                }
                result.insert(name)
            }
            if let current = currentName, !current.isEmpty {
                result.insert(current)
            }
            if let defaultDb = defaultDatabase, !defaultDb.isEmpty {
                result.insert(defaultDb)
            }
            return result
        }

        var discovered = Set<String>()

        let dmSQL = """
        SELECT DISTINCT DB_NAME(database_id) AS database_name
        FROM sys.dm_exec_sessions
        WHERE is_user_process = 1
        ORDER BY database_name;
        """
        if let dmRows = try? await fetchRows(dmSQL) {
            let names = cleaned(dmRows.compactMap { $0.string("database_name") })
            let sortedNames = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            logger.info("MSSQL listDatabases dm_exec_sessions yielded \(sortedNames)")
            discovered.formUnion(names)
        }

        let catalogSQL = """
        SELECT name
        FROM sys.databases
        WHERE state_desc = 'ONLINE'
          AND (HAS_DBACCESS(name) = 1 OR name = DB_NAME())
        ORDER BY name;
        """
        if let rows = try? await fetchRows(catalogSQL) {
            let names = cleaned(rows.compactMap { $0.string("name") })
            let sortedNames = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            logger.info("MSSQL listDatabases sys.databases yielded \(sortedNames)")
            discovered.formUnion(names)
        }

        if let procedureRows = try? await fetchRows("EXEC sp_databases;"),
           !procedureRows.isEmpty {
            let names = cleaned(procedureRows.compactMap { $0.string("DATABASE_NAME") })
            let sortedNames = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            logger.info("MSSQL listDatabases sp_databases yielded \(sortedNames)")
            discovered.formUnion(names)
        }

        if discovered.isEmpty {
            let systemFallback = cleaned([], includeSystem: true)
            let sortedFallback = systemFallback.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            logger.info("MSSQL listDatabases fallback to system set \(sortedFallback)")
            return systemFallback.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }

        let sorted = discovered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        logger.info("MSSQL listDatabases final set \(sorted)")
        return sorted
    }

    func listSchemas() async throws -> [String] {
        let sql = """
        SELECT name
        FROM sys.schemas
        WHERE name NOT IN ('sys', 'INFORMATION_SCHEMA')
        ORDER BY name;
        """
        let rows = try await fetchRows(sql)
        let names = rows.compactMap { $0.string("name") }
        logger.info("MSSQL listSchemas fetched \(names.count) schemas")
        if !names.isEmpty {
            return names
        }

        if let fallbackRows = try? await fetchRows("SELECT schema_name AS name FROM INFORMATION_SCHEMA.SCHEMATA ORDER BY schema_name"),
           !fallbackRows.isEmpty {
            let fallbackNames = fallbackRows.compactMap { $0.string("name") }
            logger.info("MSSQL listSchemas fallback via INFORMATION_SCHEMA returned \(fallbackNames.count) schemas")
            if !fallbackNames.isEmpty {
                return fallbackNames
            }
        }

        logger.info("MSSQL listSchemas returning no schemas")
        return []
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = MSSQLSession.wrapForPaging(sql: sql, limit: limit, offset: offset)
        return try await simpleQuery(pagedSQL)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName?.isEmpty == false ? schemaName! : "dbo"
        let columnMap = try await fetchColumnsByObject(schemaName: schema)
        return columnMap[tableName] ?? []
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        let qualifiedName = "\(MSSQLSession.escapeIdentifier(schemaName)).\(MSSQLSession.escapeIdentifier(objectName))"
        switch objectType {
        case .table:
            let details = try await getTableStructureDetails(schema: schemaName, table: objectName)
            let columnLines = details.columns.map { column -> String in
                var parts: [String] = []
                parts.append("\(MSSQLSession.escapeIdentifier(column.name)) \(column.dataType)")
                if !column.isNullable { parts.append("NOT NULL") }
                if let defaultValue = column.defaultValue, !defaultValue.isEmpty {
                    parts.append("DEFAULT \(defaultValue)")
                }
                if let generated = column.generatedExpression, !generated.isEmpty {
                    parts.append("AS \(generated)")
                }
                return parts.joined(separator: " ")
            }
            var statement = "CREATE TABLE \(qualifiedName) (\n    \(columnLines.joined(separator: ",\n    "))"
            if let pk = details.primaryKey {
                let columns = pk.columns.map { MSSQLSession.escapeIdentifier($0) }.joined(separator: ", ")
                statement.append(",\n    CONSTRAINT \(MSSQLSession.escapeIdentifier(pk.name)) PRIMARY KEY (\(columns))")
            }
            statement.append("\n);")
            return statement
        case .materializedView:
            return "-- Materialized views are not supported on SQL Server"
        case .view:
            let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)'));"
            if let definition = try await firstString(sql) {
                return definition
            }
            return "-- View definition unavailable"
        case .function:
            let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)'));"
            if let definition = try await firstString(sql) {
                return definition
            }
            return "-- Function definition unavailable"
        case .trigger:
            let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)'));"
            if let definition = try await firstString(sql) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let wrappedSQL = """
        SET NOCOUNT ON;
        \(sql);
        SELECT @@ROWCOUNT AS affected_rows;
        """
        let rows = try await fetchRows(wrappedSQL)
        guard let last = rows.last, let value = last.string("affected_rows"), let count = Int(value) else {
            return 0
        }
        return count
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let columns = try await loadTableColumns(schema: schema, table: table)
        let primaryKey = try await loadPrimaryKey(schema: schema, table: table)
        let indexes = try await loadIndexes(schema: schema, table: table)
        let uniqueConstraints = try await loadUniqueConstraints(schema: schema, table: table)
        let foreignKeys = try await loadForeignKeys(schema: schema, table: table)
        let dependencies = try await loadDependencies(schema: schema, table: table)
        return TableStructureDetails(
            columns: columns,
            primaryKey: primaryKey,
            indexes: indexes,
            uniqueConstraints: uniqueConstraints,
            foreignKeys: foreignKeys,
            dependencies: dependencies
        )
    }

    // MARK: - Metadata Helpers

    private func fetchRows(_ sql: String) async throws -> [MSSQLRow] {
        let future = connection.rawSql(sql)
        let rows = try await future.get()
        return rows.map { MSSQLRow(row: $0, formatter: formatter) }
    }

    private func describeColumns(for sql: String) async throws -> [ColumnInfo] {
        let escaped = MSSQLSession.escapeForNVarchar(sql)
        let describeSQL = """
        EXEC sp_describe_first_result_set @tsql = N'\(escaped)';
        """
        let rows = try await fetchRows(describeSQL)
        var columns: [ColumnInfo] = []
        for row in rows {
            if MSSQLSession.boolValue(from: row.string("is_hidden")) {
                continue
            }
            guard let name = row.string("name"), !name.isEmpty else { continue }
            let typeName = row.string("system_type_name") ?? ""
            let isNullable = MSSQLSession.boolValue(from: row.string("is_nullable"), default: true)
            let rawLength = row.string("max_length").flatMap { Int($0) }
            let maxLength = rawLength.flatMap { $0 >= 0 ? $0 : nil }
            columns.append(
                ColumnInfo(
                    name: name,
                    dataType: typeName,
                    isPrimaryKey: false,
                    isNullable: isNullable,
                    maxLength: maxLength
                )
            )
        }
        return columns
    }

    private func makeColumnInfo(from row: MSSQLRow) -> [ColumnInfo] {
        row.metadata.map { column in
            ColumnInfo(
                name: column.colName,
                dataType: MSSQLSession.displayType(for: column),
                isPrimaryKey: false,
                isNullable: (column.flags & 0x01) != 0,
                maxLength: MSSQLSession.normalizedLength(for: column)
            )
        }
    }

    private func formatRow(_ row: MSSQLRow, columns: [ColumnInfo]) -> [String?] {
        columns.map { column in
            guard let data = row.row.column(column.name) else { return nil }
            if data.value == nil { return nil }
            return formatter.stringValue(for: data)
        }
    }

    private func firstString(_ sql: String) async throws -> String? {
        let rows = try await fetchRows(sql)
        guard let firstRow = rows.first, let firstColumn = firstRow.metadata.first else { return nil }
        return firstRow.string(firstColumn.colName)
    }

    private func currentDatabaseName() async throws -> String? {
        let rows = try await fetchRows("SELECT DB_NAME() AS name;")
        return rows.first?.string("name")
    }

    private func resolvedCurrentDatabase() async -> String? {
        do {
            let name = try await currentDatabaseName()
            if let name {
                logger.debug("Resolved current database: \(name)")
            }
            return name
        } catch {
            logger.debug("Unable to resolve current database name: \(error.localizedDescription)")
            return nil
        }
    }

    private func fetchColumnsByObject(schemaName: String) async throws -> [String: [ColumnInfo]] {
        logger.info("MSSQL fetchColumnsByObject for schema \(schemaName) started")
        let sql = """
        SELECT
            c.TABLE_NAME,
            c.COLUMN_NAME,
            c.DATA_TYPE,
            c.IS_NULLABLE,
            c.CHARACTER_MAXIMUM_LENGTH,
            c.NUMERIC_PRECISION,
            c.NUMERIC_SCALE,
            COLUMNPROPERTY(object_id(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsIdentity') AS is_identity,
            COLUMNPROPERTY(object_id(c.TABLE_SCHEMA + '.' + c.TABLE_NAME), c.COLUMN_NAME, 'IsComputed') AS is_computed,
            c.ORDINAL_POSITION
        FROM INFORMATION_SCHEMA.COLUMNS AS c
        WHERE c.TABLE_SCHEMA = '\(MSSQLSession.escapeLiteral(schemaName))'
        ORDER BY c.TABLE_NAME, c.ORDINAL_POSITION;
        """

        let rows: [MSSQLRow]
        do {
            rows = try await fetchRows(sql)
        } catch {
            logger.warning("MSSQL fetchColumnsByObject for schema \(schemaName) failed: \(error.localizedDescription)")
            return [:]
        }
        logger.info("MSSQL fetchColumnsByObject for schema \(schemaName) received \(rows.count) column rows")
        let primaryKeyMap = try await loadPrimaryKeyColumns(schema: schemaName)

        var columnsByTable: [String: [ColumnInfo]] = [:]
        for row in rows {
            guard
                let tableName = row.string("TABLE_NAME"),
                let columnName = row.string("COLUMN_NAME"),
                let dataType = row.string("DATA_TYPE")
            else { continue }

            let maxLength = row.string("CHARACTER_MAXIMUM_LENGTH").flatMap { Int($0) }
            let isNullable = (row.string("IS_NULLABLE") ?? "YES").uppercased() == "YES"
            let isPrimary = primaryKeyMap[tableName]?.contains(columnName) ?? false

            let columnInfo = ColumnInfo(
                name: columnName,
                dataType: MSSQLSession.formatTypeName(base: dataType, maxLength: maxLength, precision: row.string("NUMERIC_PRECISION"), scale: row.string("NUMERIC_SCALE")),
                isPrimaryKey: isPrimary,
                isNullable: isNullable,
                maxLength: maxLength
            )

            columnsByTable[tableName, default: []].append(columnInfo)
        }

        logger.info("MSSQL fetchColumnsByObject for schema \(schemaName) produced \(columnsByTable.count) tables")
        return columnsByTable
    }

    private func loadPrimaryKeyColumns(schema: String) async throws -> [String: Set<String>] {
        let sql = """
        SELECT
            tc.TABLE_NAME,
            kcu.COLUMN_NAME
        FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS AS tc
        JOIN INFORMATION_SCHEMA.KEY_COLUMN_USAGE AS kcu
            ON tc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME
            AND tc.TABLE_SCHEMA = kcu.TABLE_SCHEMA
        WHERE tc.CONSTRAINT_TYPE = 'PRIMARY KEY'
          AND tc.TABLE_SCHEMA = '\(MSSQLSession.escapeLiteral(schema))';
        """
        let rows = try await fetchRows(sql)
        var map: [String: Set<String>] = [:]
        for row in rows {
            guard let table = row.string("TABLE_NAME"), let column = row.string("COLUMN_NAME") else { continue }
            var set = map[table] ?? []
            set.insert(column)
            map[table] = set
        }
        return map
    }

    private func loadTableColumns(schema: String, table: String) async throws -> [TableStructureDetails.Column] {
        let sql = """
        SELECT
            c.name AS column_name,
            TYPE_NAME(c.user_type_id) AS data_type,
            c.is_nullable,
            OBJECT_DEFINITION(c.default_object_id) AS column_default,
            cc.definition AS generated_expression,
            c.column_id
        FROM sys.columns AS c
        LEFT JOIN sys.computed_columns AS cc
            ON c.object_id = cc.object_id AND c.column_id = cc.column_id
        WHERE c.object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
        ORDER BY c.column_id;
        """
        let rows = try await fetchRows(sql)
        return rows.compactMap { row in
            guard let name = row.string("column_name"), let dataType = row.string("data_type") else { return nil }
            let isNullable = MSSQLSession.boolValue(from: row.string("is_nullable"), default: true)
            let defaultValue = row.string("column_default")?.trimmingCharacters(in: .whitespacesAndNewlines)
            let generated = row.string("generated_expression")?.trimmingCharacters(in: .whitespacesAndNewlines)
            return TableStructureDetails.Column(
                name: name,
                dataType: dataType,
                isNullable: isNullable,
                defaultValue: defaultValue,
                generatedExpression: generated
            )
        }
    }

    private func loadPrimaryKey(schema: String, table: String) async throws -> TableStructureDetails.PrimaryKey? {
        let sql = """
        SELECT
            kc.name AS constraint_name,
            c.name AS column_name
        FROM sys.key_constraints AS kc
        JOIN sys.index_columns AS ic
            ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
        JOIN sys.columns AS c
            ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE kc.parent_object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
          AND kc.type = 'PK'
        ORDER BY ic.key_ordinal;
        """
        let rows = try await fetchRows(sql)
        guard let name = rows.first?.string("constraint_name") else { return nil }
        let columns = rows.compactMap { $0.string("column_name") }
        return TableStructureDetails.PrimaryKey(name: name, columns: columns)
    }

    private func loadIndexes(schema: String, table: String) async throws -> [TableStructureDetails.Index] {
        let sql = """
        SELECT
            i.name AS index_name,
            i.is_unique,
            ic.key_ordinal,
            c.name AS column_name,
            ic.is_descending_key,
            i.has_filter,
            i.filter_definition
        FROM sys.indexes AS i
        JOIN sys.index_columns AS ic
            ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        JOIN sys.columns AS c
            ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
          AND i.is_primary_key = 0
          AND i.[type] <> 0
        ORDER BY i.name, ic.key_ordinal;
        """
        let rows = try await fetchRows(sql)
        var indexes: [String: MSSQLIndexAccumulator] = [:]
        for row in rows {
            guard let indexName = row.string("index_name") else { continue }
            var accumulator = indexes[indexName] ?? MSSQLIndexAccumulator(isUnique: MSSQLSession.boolValue(from: row.string("is_unique")), filterDefinition: row.string("filter_definition"))
            if let columnName = row.string("column_name"), let ordinalString = row.string("key_ordinal"), let ordinal = Int(ordinalString) {
                let descending = MSSQLSession.boolValue(from: row.string("is_descending_key"))
                accumulator.columns.append(
                    TableStructureDetails.Index.Column(
                        name: columnName,
                        position: ordinal,
                        sortOrder: descending ? .descending : .ascending
                    )
                )
            }
            indexes[indexName] = accumulator
        }
        return indexes.map { name, value in
            TableStructureDetails.Index(
                name: name,
                columns: value.columns.sorted { $0.position < $1.position },
                isUnique: value.isUnique,
                filterCondition: value.filterDefinition?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadUniqueConstraints(schema: String, table: String) async throws -> [TableStructureDetails.UniqueConstraint] {
        let sql = """
        SELECT
            kc.name AS constraint_name,
            c.name AS column_name,
            ic.key_ordinal
        FROM sys.key_constraints AS kc
        JOIN sys.index_columns AS ic
            ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
        JOIN sys.columns AS c
            ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE kc.parent_object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
          AND kc.type = 'UQ'
        ORDER BY kc.name, ic.key_ordinal;
        """
        let rows = try await fetchRows(sql)
        var constraints: [String: [String]] = [:]
        for row in rows {
            guard let name = row.string("constraint_name"), let column = row.string("column_name") else { continue }
            constraints[name, default: []].append(column)
        }
        return constraints.map { name, columns in
            TableStructureDetails.UniqueConstraint(name: name, columns: columns)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadForeignKeys(schema: String, table: String) async throws -> [TableStructureDetails.ForeignKey] {
        let sql = """
        SELECT
            fk.name AS constraint_name,
            parent_c.name AS column_name,
            OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS referenced_schema,
            OBJECT_NAME(fk.referenced_object_id) AS referenced_table,
            referenced_c.name AS referenced_column,
            fk.update_referential_action_desc,
            fk.delete_referential_action_desc,
            fkc.constraint_column_id
        FROM sys.foreign_keys AS fk
        JOIN sys.foreign_key_columns AS fkc
            ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns AS parent_c
            ON fkc.parent_object_id = parent_c.object_id AND fkc.parent_column_id = parent_c.column_id
        JOIN sys.columns AS referenced_c
            ON fkc.referenced_object_id = referenced_c.object_id AND fkc.referenced_column_id = referenced_c.column_id
        WHERE fk.parent_object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
        ORDER BY fk.name, fkc.constraint_column_id;
        """
        let rows = try await fetchRows(sql)
        let grouped = Dictionary(grouping: rows, by: { $0.string("constraint_name") ?? "" })
        return grouped.compactMap { (name, entries) -> TableStructureDetails.ForeignKey? in
            guard !name.isEmpty else { return nil }
            let sorted = entries.sorted { (lhs, rhs) -> Bool in
                let l = Int(lhs.string("constraint_column_id") ?? "0") ?? 0
                let r = Int(rhs.string("constraint_column_id") ?? "0") ?? 0
                return l < r
            }
            guard let first = sorted.first else { return nil }
            let columns = sorted.compactMap { $0.string("column_name") }
            let referencedColumns = sorted.compactMap { $0.string("referenced_column") }
            let referencedSchema = first.string("referenced_schema") ?? schema
            let referencedTable = first.string("referenced_table") ?? ""
            let onUpdate = first.string("update_referential_action_desc")
            let onDelete = first.string("delete_referential_action_desc")
            return TableStructureDetails.ForeignKey(
                name: name,
                columns: columns,
                referencedSchema: referencedSchema,
                referencedTable: referencedTable,
                referencedColumns: referencedColumns,
                onUpdate: onUpdate,
                onDelete: onDelete
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadDependencies(schema: String, table: String) async throws -> [TableStructureDetails.Dependency] {
        let sql = """
        SELECT
            fk.name AS constraint_name,
            OBJECT_SCHEMA_NAME(fk.parent_object_id) AS referencing_schema,
            OBJECT_NAME(fk.parent_object_id) AS referencing_table,
            parent_c.name AS referencing_column,
            referenced_c.name AS referenced_column,
            fk.update_referential_action_desc,
            fk.delete_referential_action_desc,
            fkc.constraint_column_id
        FROM sys.foreign_keys AS fk
        JOIN sys.foreign_key_columns AS fkc
            ON fk.object_id = fkc.constraint_object_id
        JOIN sys.columns AS parent_c
            ON fkc.parent_object_id = parent_c.object_id AND fkc.parent_column_id = parent_c.column_id
        JOIN sys.columns AS referenced_c
            ON fkc.referenced_object_id = referenced_c.object_id AND fkc.referenced_column_id = referenced_c.column_id
        WHERE fk.referenced_object_id = OBJECT_ID(N'\(MSSQLSession.escapeIdentifier(schema)).\(MSSQLSession.escapeIdentifier(table))')
        ORDER BY fk.name, fkc.constraint_column_id;
        """
        let rows = try await fetchRows(sql)
        let grouped = Dictionary(grouping: rows, by: { $0.string("constraint_name") ?? "" })
        return grouped.compactMap { (name, entries) -> TableStructureDetails.Dependency? in
            guard !name.isEmpty else { return nil }
            let sorted = entries.sorted { (lhs, rhs) -> Bool in
                let l = Int(lhs.string("constraint_column_id") ?? "0") ?? 0
                let r = Int(rhs.string("constraint_column_id") ?? "0") ?? 0
                return l < r
            }
            guard let first = sorted.first else { return nil }
            let baseColumns = sorted.compactMap { $0.string("referencing_column") }
            let referencedColumns = sorted.compactMap { $0.string("referenced_column") }
            let referencingSchema = first.string("referencing_schema") ?? schema
            let referencingTableName = first.string("referencing_table") ?? ""
            let tableName: String
            if referencingSchema == schema {
                tableName = referencingTableName
            } else {
                tableName = "\(referencingSchema).\(referencingTableName)"
            }
            let onUpdate = first.string("update_referential_action_desc")
            let onDelete = first.string("delete_referential_action_desc")
            return TableStructureDetails.Dependency(
                name: name,
                baseColumns: baseColumns,
                referencedTable: tableName,
                referencedColumns: referencedColumns,
                onUpdate: onUpdate,
                onDelete: onDelete
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func wrapForPaging(sql: String, limit: Int, offset: Int) -> String {
        let start = offset + 1
        let end = offset + limit
        return """
        SELECT *
        FROM (
            SELECT ROW_NUMBER() OVER (ORDER BY (SELECT 1)) AS __rownum, inner_query.*
            FROM (
                \(sql)
            ) AS inner_query
        ) AS numbered
        WHERE __rownum BETWEEN \(start) AND \(end)
        ORDER BY __rownum;
        """
    }

    private static func displayType(for column: TDSTokens.ColMetadataToken.ColumnData) -> String {
        switch column.dataType {
        case .nvarchar, .nchar, .varchar, .char:
            if column.length == -1 {
                return "\(column.dataType)(MAX)"
            }
            let length = normalizedLength(for: column) ?? column.length
            return "\(column.dataType)(\(length))"
        case .decimal, .numeric:
            let precision = column.precision ?? 0
            let scale = column.scale ?? 0
            return "\(column.dataType)(\(precision), \(scale))"
        default:
            return String(describing: column.dataType)
        }
    }

    private static func normalizedLength(for column: TDSTokens.ColMetadataToken.ColumnData) -> Int? {
        guard column.length > 0 else { return nil }
        switch column.dataType {
        case .nvarchar, .nchar, .nText:
            return column.length / 2
        default:
            return column.length
        }
    }

    private static func formatTypeName(base: String, maxLength: Int?, precision: String?, scale: String?) -> String {
        switch base.lowercased() {
        case "nvarchar", "nchar", "varchar", 
            "char" where maxLength != nil:
            if let maxLength, maxLength == -1 {
                return "\(base)(MAX)"
            }
            if let maxLength {
                let normalized = base.lowercased().hasPrefix("n") ? maxLength / 2 : maxLength
                return "\(base)(\(max(normalized, 0)))"
            }
            return base
        case "decimal", "numeric":
            if let precision, let scale {
                return "\(base)(\(precision), \(scale))"
            }
            return base
        default:
            return base
        }
    }

    private static func escapeIdentifier(_ value: String) -> String {
        "[\(value.replacingOccurrences(of: "]", with: "]]"))]"
    }

    private static func escapeLiteral(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private static func escapeForNVarchar(_ value: String) -> String {
        value.replacingOccurrences(of: "'", with: "''")
    }

    private static func boolValue(from string: String?, default defaultValue: Bool = false) -> Bool {
        guard let string else { return defaultValue }
        switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        case "0", "false", "no", "n", "off":
            return false
        default:
            return defaultValue
        }
    }

    static func metadataColumns(from metadata: TDSTokens.ColMetadataToken) -> [TDSTokens.ColMetadataToken.ColumnData] {
        let mirror = Mirror(reflecting: metadata)
        for child in mirror.children where child.label == "colData" {
            if let value = child.value as? [TDSTokens.ColMetadataToken.ColumnData] {
                return value
            }
        }
        return []
    }
}

extension MSSQLSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        logger.debug("MSSQL loadSchemaInfo starting for schema \(schemaName)")
        let columnMap = try await fetchColumnsByObject(schemaName: schemaName)

        let tablesSQL = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = '\(MSSQLSession.escapeLiteral(schemaName))'
        ORDER BY table_name;
        """
        let tableRows = try await fetchRows(tablesSQL)
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(tableRows.count) tables/views")

        let functionSQL = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE routine_schema = '\(MSSQLSession.escapeLiteral(schemaName))'
          AND routine_type = 'FUNCTION'
        ORDER BY routine_name;
        """
        let functionRows = try await fetchRows(functionSQL)
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(functionRows.count) functions")

        let triggerSQL = """
        SELECT
            tr.name AS trigger_name,
            obj.name AS parent_name,
            CASE WHEN tr.is_instead_of_trigger = 1 THEN 'INSTEAD OF' ELSE 'AFTER' END AS timing,
            STUFF((
                SELECT ', ' + ev.type_desc
                FROM sys.trigger_events AS ev
                WHERE ev.object_id = tr.object_id
                FOR XML PATH(''), TYPE
            ).value('.', 'nvarchar(max)'), 1, 2, '') AS event_list
        FROM sys.triggers AS tr
        JOIN sys.objects AS obj ON tr.parent_id = obj.object_id
        JOIN sys.schemas AS s ON obj.schema_id = s.schema_id
        WHERE s.name = '\(MSSQLSession.escapeLiteral(schemaName))'
        ORDER BY tr.name;
        """
        let triggerRows = try await fetchRows(triggerSQL)
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(triggerRows.count) triggers")

        let totalObjects = max(tableRows.count + functionRows.count + triggerRows.count, 1)
        var processed = 0
        var objects: [SchemaObjectInfo] = []

        for row in tableRows {
            guard let name = row.string("table_name"), let typeString = row.string("table_type") else { continue }
            let type: SchemaObjectInfo.ObjectType = typeString.uppercased() == "VIEW" ? .view : .table
            if let progress {
                await progress(type, processed, totalObjects)
            }
            processed += 1
            let columns = columnMap[name] ?? []
            objects.append(SchemaObjectInfo(name: name, schema: schemaName, type: type, columns: columns))
        }

        if let progress {
            await progress(.function, processed, totalObjects)
        }
        for row in functionRows {
            guard let name = row.string("routine_name") else { continue }
            processed += 1
            if let progress {
                await progress(.function, processed, totalObjects)
            }
            objects.append(SchemaObjectInfo(name: name, schema: schemaName, type: .function))
        }

        if let progress {
            await progress(.trigger, processed, totalObjects)
        }
        for row in triggerRows {
            guard let name = row.string("trigger_name"), let parentName = row.string("parent_name") else { continue }
            processed += 1
            if let progress {
                await progress(.trigger, processed, totalObjects)
            }
            let timing = row.string("timing") ?? ""
            let events = row.string("event_list") ?? ""
            let action = [timing, events].filter { !$0.isEmpty }.joined(separator: " ")
            let tableFull = "\(schemaName).\(parentName)"
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: .trigger,
                    columns: [],
                    triggerAction: action.isEmpty ? nil : action,
                    triggerTable: tableFull
                )
            )
        }

        logger.debug("MSSQL loadSchemaInfo completed for schema \(schemaName) with \(objects.count) objects")
        return SchemaInfo(name: schemaName, objects: objects)
    }
}

private struct MSSQLIndexAccumulator {
    var isUnique: Bool
    var filterDefinition: String?
    var columns: [TableStructureDetails.Index.Column] = []
}

private struct MSSQLRow {
    let row: TDSRow
    let formatter: MSSQLCellFormatter
    let metadata: [TDSTokens.ColMetadataToken.ColumnData]

    init(row: TDSRow, formatter: MSSQLCellFormatter) {
        self.row = row
        self.formatter = formatter
        self.metadata = MSSQLSession.metadataColumns(from: row.columnMetadata)
    }

    func string(_ column: String) -> String? {
        guard let data = row.column(column), data.value != nil else { return nil }
        return formatter.stringValue(for: data)
    }
}

private struct MSSQLCellFormatter {
    private let dateFormatter: DateFormatter
    private let timestampFormatter: ISO8601DateFormatter

    init() {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd"
        self.dateFormatter = dateFormatter

        let timestampFormatter = ISO8601DateFormatter()
        timestampFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        timestampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        self.timestampFormatter = timestampFormatter
    }

    func stringValue(for data: TDSData) -> String? {
        guard var buffer = data.value else { return nil }
        switch data.metadata.dataType {
        case .bit, .bitn:
            return data.bool.map { $0 ? "true" : "false" }
        case .tinyInt:
            return data.uint8.map { String($0) }
        case .smallInt:
            return data.int16.map { String($0) }
        case .int:
            return data.int32.map { String($0) }
        case .bigInt, .intn:
            if let value = data.int64 {
                return String(value)
            }
            if let value = data.uint64 {
                return String(value)
            }
        case .real, .float, .floatn, .money, .smallMoney, .moneyn, .decimal, .numeric:
            if let double = data.double {
                return formatFloatingPoint(double)
            }
        case .date, .datetime, .datetime2, .datetimeOffset, .smallDateTime, .datetimen:
            if let date = data.date {
                if data.metadata.dataType == .date {
                    return dateFormatter.string(from: date)
                } else {
                    return timestampFormatter.string(from: date)
                }
            }
        case .time:
            return formatTime(from: &buffer, scale: data.metadata.scale ?? 7)
        case .char, .varchar, .text, .varcharLegacy, .charLegacy:
            return decodeSingleByteString(from: &buffer)
        case .nvarchar, .nchar, .nText:
            return decodeUnicodeString(from: &buffer)
        case .binary, .varbinary, .binaryLegacy, .varbinaryLegacy:
            return hexString(from: &buffer)
        case .guid:
            return formatGUID(from: &buffer)
        default:
            break
        }
        return hexString(from: &buffer)
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

    private func formatTime(from buffer: inout ByteBuffer, scale: Int) -> String? {
        let length = buffer.readableBytes
        guard length > 0, let bytes = buffer.readBytes(length: length) else { return nil }
        var increments = 0
        for (index, byte) in bytes.enumerated() {
            increments |= Int(byte) << (index * 8)
        }
        if scale < 7 {
            for _ in scale..<7 {
                increments *= 10
            }
        }
        let totalNanoseconds = Double(increments) * 100.0
        let totalSeconds = totalNanoseconds / 1_000_000_000.0
        let hours = Int(totalSeconds / 3600)
        let minutes = Int((totalSeconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = totalSeconds.truncatingRemainder(dividingBy: 60)
        let wholeSeconds = Int(seconds)
        let fractional = seconds - Double(wholeSeconds)
        if fractional == 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, wholeSeconds)
        }
        let fractionalString = String(format: "%.7f", fractional).dropFirst(2).trimmingCharacters(in: CharacterSet(charactersIn: "0"))
        return String(format: "%02d:%02d:%02d.%@", hours, minutes, wholeSeconds, fractionalString)
    }

    private func formatGUID(from buffer: inout ByteBuffer) -> String? {
        guard buffer.readableBytes == 16,
              let data1 = buffer.readInteger(endianness: .little, as: UInt32.self),
              let data2 = buffer.readInteger(endianness: .little, as: UInt16.self),
              let data3 = buffer.readInteger(endianness: .little, as: UInt16.self),
              let remainder = buffer.readBytes(length: 8)
        else {
            return nil
        }
        return String(format: "%08X-%04X-%04X-%02X%02X-%02X%02X%02X%02X%02X%02X", data1, data2, data3, remainder[0], remainder[1], remainder[2], remainder[3], remainder[4], remainder[5], remainder[6], remainder[7])
    }

    private func hexString(from buffer: inout ByteBuffer) -> String {
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else { return "" }
        return bytes.reduce(into: "0x") { partialResult, byte in
            partialResult.append(String(format: "%02X", byte))
        }
    }
    private func decodeUnicodeString(from buffer: inout ByteBuffer) -> String? {
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else { return nil }
        return String(bytes: bytes, encoding: .utf16LittleEndian)
    }

    private func decodeSingleByteString(from buffer: inout ByteBuffer) -> String? {
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else { return nil }
        if let utf8 = String(bytes: bytes, encoding: .utf8) {
            return utf8
        }
        if let latin1 = String(bytes: bytes, encoding: .isoLatin1) {
            return latin1
        }
        let characters = bytes.compactMap { UnicodeScalar($0) }.map { Character($0) }
        return String(characters)
    }
}
