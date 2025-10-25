import Foundation
import Logging
import NIOCore
import NIOSSL
import SQLServerKit

struct MSSQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mssql")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        let databaseName = database ?? ""
        let login: TDSAuthentication
        switch authentication.method {
        case .sqlPassword:
            guard let password = authentication.password else {
                throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
            }
            login = .sqlPassword(username: authentication.username, password: password)
        case .windowsIntegrated:
            throw DatabaseError.authenticationFailed(
                "Windows integrated authentication is not supported by the current SQL Server driver"
            )
        }

        // Configure metadata client to include all user databases
        var metadataConfiguration = SQLServerMetadataClient.Configuration()
        metadataConfiguration.includeSystemSchemas = false
//        metadataConfiguration.includeSystemObjects = false

        let configuration = SQLServerConnection.Configuration(
            hostname: host,
            port: port,
            login: .init(database: databaseName, authentication: login),
            tlsConfiguration: tls ? TLSConfiguration.makeClientConfiguration() : nil,
            metadataConfiguration: metadataConfiguration
        )

        let connection = try await SQLServerConnection.connect(
            configuration: configuration,
            eventLoopGroupProvider: .createNew(numberOfThreads: 1),
            logger: logger
        ).get()

        let session = MSSQLSession(
            connection: connection,
            logger: logger,
            defaultDatabase: database
        )
        try await session.bootstrap()
        return session
    }
}

final class MSSQLSession: DatabaseSession {
    private let connection: SQLServerConnection
    private let logger: Logger
    private let defaultDatabase: String?
    private nonisolated(unsafe) let formatter = MSSQLCellFormatter()
    private let databaseContext = MSSQLDatabaseContext()
    private nonisolated(unsafe) var isClosed = false

    init(connection: SQLServerConnection, logger: Logger, defaultDatabase: String?) {
        self.connection = connection
        self.logger = logger
        self.defaultDatabase = defaultDatabase
    }

    func bootstrap() async throws {
        try await applySessionDefaults()
        try await ensureDefaultDatabaseContext()
    }

    deinit {
        if !isClosed {
            _ = connection.close()
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
    }

    private func applySessionDefaults() async throws {
        let defaultsSQL = """
        SET ANSI_NULLS ON;
        SET ANSI_WARNINGS ON;
        SET ARITHABORT ON;
        SET QUOTED_IDENTIFIER ON;
        SET NOCOUNT OFF;
        SET FMTONLY OFF;
        """
        do {
            _ = try await connection.query(defaultsSQL)
            logger.info("MSSQL session defaults applied (SET FMTONLY OFF)")
            await databaseContext.reset()
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await ensureDefaultDatabaseContext()
        var resolvedColumns: [ColumnInfo] = []
        var shouldDropRowNumberColumn = false

        var previewRows: [[String?]] = []
        previewRows.reserveCapacity(512)
        var totalRowCount = 0

        let operationStart = CFAbsoluteTimeGetCurrent()
        let streamingPreviewLimit = 512
        let maxFlushLatency: TimeInterval = 0.015

        let bridgedHandler: QueryProgressHandler? = progressHandler.map { handler -> QueryProgressHandler in
            let sendableHandler: QueryProgressHandler = { update in
                Task { @MainActor in
                    handler(update)
                }
            }
            return sendableHandler
        }

        var worker: ResultStreamBatchWorker?

        func ensureWorker(with columns: [ColumnInfo]) {
            guard worker == nil, let handler = bridgedHandler, !columns.isEmpty else { return }
            worker = ResultStreamBatchWorker(
                label: "dk.tippr.echo.mssql.streamWorker",
                columns: columns,
                streamingPreviewLimit: streamingPreviewLimit,
                maxFlushLatency: maxFlushLatency,
                operationStart: operationStart,
                progressHandler: handler
            )
        }

        do {
            for try await event in connection.streamQuery(sql) {
                switch event {
                case .metadata(let metadata):
                    logger.info("MSSQL streamQuery metadata for SQL (first 64 chars): \(sql.prefix(64)) … -> \(metadata.count) columns")
                    if resolvedColumns.isEmpty {
                        resolvedColumns = makeColumnInfo(from: metadata)
                        if let first = resolvedColumns.first, first.name == "__rownum" {
                            resolvedColumns.removeFirst()
                            shouldDropRowNumberColumn = true
                        }
                        ensureWorker(with: resolvedColumns)
                    }
                case .row(let rawRow):
                    if Task.isCancelled {
                        throw CancellationError()
                    }

                    let wrappedRow = MSSQLRow(row: rawRow, formatter: formatter)

                    if resolvedColumns.isEmpty {
                        resolvedColumns = makeColumnInfo(from: wrappedRow)
                        if let first = resolvedColumns.first, first.name == "__rownum" {
                            resolvedColumns.removeFirst()
                            shouldDropRowNumberColumn = true
                        }
                        ensureWorker(with: resolvedColumns)
                    }

                    guard !resolvedColumns.isEmpty else { continue }

                    let decodeStart = CFAbsoluteTimeGetCurrent()
                    var formatted = formatRow(wrappedRow, columns: resolvedColumns)
                    if shouldDropRowNumberColumn, formatted.count > resolvedColumns.count {
                        formatted.removeFirst()
                    }
                    let decodeDuration = CFAbsoluteTimeGetCurrent() - decodeStart

                    totalRowCount += 1
                    if previewRows.count < streamingPreviewLimit {
                        previewRows.append(formatted)
                    }

                    if let worker {
                        let payload = ResultStreamBatchWorker.Payload(
                            previewValues: totalRowCount <= streamingPreviewLimit ? formatted : nil,
                            storage: .encoded(ResultBinaryRowCodec.encode(row: formatted)),
                            totalRowCount: totalRowCount,
                            decodeDuration: decodeDuration
                        )
                        worker.enqueue(payload)
                    }
                case .done(let done):
                    logger.info("MSSQL streamQuery DONE status=\(done.status) rowCount=\(done.rowCount)")
                case .message(let message):
                    switch message.kind {
                    case .info:
                        logger.info("MSSQL streamQuery info message \(message.number): \(message.message)")
                    case .error:
                        logger.error("MSSQL streamQuery error \(message.number): \(message.message)")
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        worker?.finish(totalRowCount: totalRowCount)

        if Task.isCancelled {
            throw CancellationError()
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
        try await ensureDefaultDatabaseContext()
        let schemaName = schema?.isEmpty == false ? schema! : "dbo"
        let currentDatabase = await resolvedCurrentDatabase()
        let tableMetadata: [TableMetadata]
        do {
            let rawTables = try await connection.listTables(database: currentDatabase, schema: schemaName)
            tableMetadata = rawTables.filter { !$0.isSystemObject && !$0.name.hasPrefix("meta_client_") && !$0.name.hasPrefix("#") }
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
        let primaryKeyMap = try await loadPrimaryKeyColumns(schema: schemaName)
        var objects: [SchemaObjectInfo] = []
        for table in tableMetadata {
            let baseColumns: [ColumnMetadata]
            do {
                baseColumns = try await connection.listColumns(database: currentDatabase, schema: table.schema, table: table.name)
            } catch let sqlError as SQLServerError {
                if case .connectionClosed = sqlError {
                    throw MSSQLSessionError.connectionClosed
                }
                throw DatabaseError.queryError(sqlError.description)
            } catch {
                throw DatabaseError.queryError(error.localizedDescription)
            }
            let columnInfos: [ColumnInfo] = baseColumns.sorted { $0.ordinalPosition < $1.ordinalPosition }.map { metadata in
                ColumnInfo(
                    name: metadata.name,
                    dataType: MSSQLSession.formatTypeName(
                        base: metadata.typeName,
                        maxLength: metadata.maxLength,
                        precision: metadata.precision.map { String($0) },
                        scale: metadata.scale.map { String($0) }
                    ),
                    isPrimaryKey: primaryKeyMap[table.name]?.contains(metadata.name) ?? false,
                    isNullable: metadata.isNullable,
                    maxLength: metadata.maxLength
                )
            }
            let objectType: SchemaObjectInfo.ObjectType = table.type.lowercased().contains("view") ? .view : .table
            objects.append(SchemaObjectInfo(name: table.name, schema: table.schema, type: objectType, columns: columnInfos))
        }
        return objects
    }

    func listDatabases() async throws -> [String] {
        logger.info("Listing MSSQL databases using SQLServerKit API")

        do {
            // Use the SQLServerKit metadata client to list databases
            let databases = try await connection.listDatabases()
            
            // Filter to only include online, accessible databases
            let names = databases
//                .filter { !$0.isSystemDatabase }
                .map { $0.name }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            
            logger.info("MSSQL listDatabases found \(names.count) user databases: \(names)")
            return names
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            logger.error("MSSQL listDatabases failed: \(sqlError.description)")
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            logger.error("MSSQL listDatabases failed: \(error.localizedDescription)")
            throw DatabaseError.queryError(error.localizedDescription)
        }
    }

    func listSchemas() async throws -> [String] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let schemas: [SchemaMetadata]
        do {
            schemas = try await connection.listSchemas(in: currentDatabase)
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }
        let filtered = schemas
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { name in
                let lowered = name.lowercased()
                if lowered == "sys" || lowered == "information_schema" || lowered == "guest" {
                    return false
                }
                if lowered.hasPrefix("db_") {
                    return false
                }
                return true
            }
        logger.info("MSSQL listSchemas fetched \(filtered.count) schemas")
        if !filtered.isEmpty {
            logger.debug("MSSQL listSchemas filtered names: \(filtered)")
        }
        return filtered.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        try await ensureDefaultDatabaseContext()
        let pagedSQL = MSSQLSession.wrapForPaging(sql: sql, limit: limit, offset: offset)
        return try await simpleQuery(pagedSQL)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        try await ensureDefaultDatabaseContext()
        let schema = schemaName?.isEmpty == false ? schemaName! : "dbo"
        let currentDatabase = await resolvedCurrentDatabase()
        let metadata: [ColumnMetadata]
        do {
            metadata = try await connection.listColumns(database: currentDatabase, schema: schema, table: tableName)
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        let columnInfos = metadata.sorted { $0.ordinalPosition < $1.ordinalPosition }.map { column in
            ColumnInfo(
                name: column.name,
                dataType: MSSQLSession.formatTypeName(
                    base: column.typeName,
                    maxLength: column.maxLength,
                    precision: column.precision.map { String($0) },
                    scale: column.scale.map { String($0) }
                ),
                isPrimaryKey: false,
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
        let primaryKeyMap = try await loadPrimaryKeyColumns(schema: schema)
        return columnInfos.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.dataType,
                isPrimaryKey: primaryKeyMap[tableName]?.contains(column.name) ?? false,
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        try await ensureDefaultDatabaseContext()
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
        case .procedure:
            let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)'));"
            if let definition = try await firstString(sql) {
                return definition
            }
            return "-- Procedure definition unavailable"
        case .trigger:
            let sql = "SELECT OBJECT_DEFINITION(OBJECT_ID(N'\(qualifiedName)'));"
            if let definition = try await firstString(sql) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        try await ensureDefaultDatabaseContext()
        let wrappedSQL = """
        SET NOCOUNT ON;
        \(sql);
        SELECT @@ROWCOUNT AS affected_rows;
        """
        let rows = try await collectRows(wrappedSQL)
        guard let last = rows.last, let value = last.string("affected_rows"), let count = Int(value) else {
            return 0
        }
        return count
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        try await ensureDefaultDatabaseContext()
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

    private func buildColumnMapUsingMetadataClient(schemaName: String) async throws -> [String: [ColumnInfo]] {
        var columnMap: [String: [ColumnInfo]] = [:]
        let currentDatabase = await resolvedCurrentDatabase()
        let tables: [TableMetadata]
        do {
            tables = try await connection.listTables(database: currentDatabase, schema: schemaName)
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        guard !tables.isEmpty else {
            return [:]
        }

        let primaryKeyMap = try await loadPrimaryKeyColumns(schema: schemaName)

        for table in tables {
            if table.isSystemObject || table.name.hasPrefix("meta_client_") || table.name.hasPrefix("#") {
                continue
            }
            let metadata: [ColumnMetadata]
            do {
                metadata = try await connection.listColumns(database: currentDatabase, schema: table.schema, table: table.name)
            } catch let sqlError as SQLServerError {
                if case .connectionClosed = sqlError {
                    throw MSSQLSessionError.connectionClosed
                }
                throw DatabaseError.queryError(sqlError.description)
            } catch {
                throw DatabaseError.queryError(error.localizedDescription)
            }

            guard !metadata.isEmpty else {
                continue
            }

            var columns: [ColumnInfo] = []
            columns.reserveCapacity(metadata.count)
            for column in metadata {
                let formattedType = MSSQLSession.formatTypeName(
                    base: column.typeName,
                    maxLength: column.maxLength,
                    precision: column.precision.map { String($0) },
                    scale: column.scale.map { String($0) }
                )
                let isPrimary = primaryKeyMap[table.name]?.contains(column.name) ?? false
                columns.append(
                    ColumnInfo(
                        name: column.name,
                        dataType: formattedType,
                        isPrimaryKey: isPrimary,
                        isNullable: column.isNullable,
                        maxLength: column.maxLength
                    )
                )
            }

            columnMap[table.name] = columns
        }

        logger.info("MSSQL metadata client produced column map with \(columnMap.count) tables for schema \(schemaName)")
        return columnMap
    }

    private func collectRows(_ sql: String) async throws -> [MSSQLRow] {
        var metadataLogged = false
        var rawRows: [TDSRow] = []

        do {
            for try await event in connection.streamQuery(sql) {
                switch event {
                case .metadata(let metadata):
                    if !metadataLogged {
                        logger.info("MSSQL collectRows metadata for SQL (first 64 chars): \(sql.prefix(64)) … -> \(metadata.count) columns")
                        metadataLogged = true
                    }
                case .row(let row):
                    rawRows.append(row)
                case .done(let done):
                    logger.info("MSSQL collectRows DONE status=\(done.status) rowCount=\(done.rowCount)")
                case .message(let message):
                    switch message.kind {
                    case .info:
                        logger.info("MSSQL collectRows info message \(message.number): \(message.message)")
                    case .error:
                        logger.error("MSSQL collectRows error \(message.number): \(message.message)")
                    }
                }
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        logger.info("MSSQL collectRows executed SQL (first 64 chars): \(sql.prefix(64)) … -> \(rawRows.count) rows")
        if !rawRows.isEmpty {
            let preview = rawRows.prefix(8)
            for (index, row) in preview.enumerated() {
                logger.info("MSSQL collectRows raw row[\(index)] = \(row)")
            }
        }

        return rawRows.map { MSSQLRow(row: $0, formatter: formatter) }
    }

    private func ensureDefaultDatabaseContext() async throws {
        try await ensureDatabaseContext(defaultDatabase)
    }

    private func ensureDatabaseContext(_ database: String?) async throws {
        guard let trimmed = database?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            if database == nil {
                await databaseContext.reset()
            }
            return
        }

        if await databaseContext.needsSwitch(to: trimmed) {
            let escaped = MSSQLSession.escapeIdentifier(trimmed)
            let sql = "USE \(escaped);"
            do {
                do {
                    _ = try await connection.query(sql)
                } catch let sqlError as SQLServerError {
                    if case .connectionClosed = sqlError {
                        await databaseContext.reset()
                        throw MSSQLSessionError.connectionClosed
                    }
                    await databaseContext.reset()
                    throw DatabaseError.queryError(sqlError.description)
                } catch {
                    await databaseContext.reset()
                    throw DatabaseError.queryError(error.localizedDescription)
                }
                await databaseContext.setActive(trimmed)
                logger.info("MSSQL session switched to database context: \(trimmed)")
            } catch let databaseError as DatabaseError {
                logger.warning("Failed to switch MSSQL session to database \(trimmed): \(databaseError.localizedDescription)")
                throw databaseError
            } catch {
                logger.warning("Failed to switch MSSQL session to database \(trimmed): \(error.localizedDescription)")
                throw DatabaseError.queryError(error.localizedDescription)
            }
        }
    }

    private func makeColumnInfo(from metadata: [SQLServerColumnDescription]) -> [ColumnInfo] {
        metadata.map { column in
            ColumnInfo(
                name: column.name,
                dataType: MSSQLSession.displayType(for: column),
                isPrimaryKey: false,
                isNullable: (column.flags & 0x01) != 0,
                maxLength: MSSQLSession.normalizedLength(for: column)
            )
        }
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
            row.string(column.name)
        }
    }

    private func firstString(_ sql: String) async throws -> String? {
        try await ensureDefaultDatabaseContext()
        let rows = try await collectRows(sql)
        guard let firstRow = rows.first, let firstColumn = firstRow.metadata.first else { return nil }
        return firstRow.string(firstColumn.colName)
    }

    private func currentDatabaseName() async throws -> String? {
        try await ensureDefaultDatabaseContext()
        let rows = try await collectRows("SELECT DB_NAME() AS name;")
        return rows.first?.string("name")
    }

    private func resolvedCurrentDatabase() async -> String? {
        do {
            let name = try await currentDatabaseName()
            if let name {
                logger.info("Resolved current database: \(name)")
            }
            return name
        } catch {
            logger.info("Unable to resolve current database name: \(error.localizedDescription)")
            return nil
        }
    }

    private func loadParameters(schemaName: String, objectNames: [String], database: String?) async throws -> [String: [ProcedureParameterInfo]] {
        guard !objectNames.isEmpty else {
            return [:]
        }
        try await ensureDefaultDatabaseContext()
        logger.info("MSSQL loadParameters for schema \(schemaName) started for \(objectNames.count) objects")
        var parametersByObject: [String: [ProcedureParameterInfo]] = [:]
        for objectName in objectNames.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
            do {
                let metadata = try await connection.listParameters(database: database, schema: schemaName, object: objectName)
                let filtered = metadata.filter { !$0.isReturnValue }
                guard !filtered.isEmpty else { continue }
                let parameters = filtered
                    .sorted { $0.ordinal < $1.ordinal }
                    .map { parameter in
                        let formattedType = MSSQLSession.formatTypeName(
                            base: parameter.typeName,
                            maxLength: parameter.maxLength,
                            precision: parameter.precision.map { String($0) },
                            scale: parameter.scale.map { String($0) }
                        )
                        return ProcedureParameterInfo(
                            name: parameter.name,
                            dataType: formattedType,
                            isOutput: parameter.isOutput,
                            hasDefaultValue: parameter.hasDefaultValue || parameter.defaultValue != nil,
                            maxLength: parameter.maxLength,
                            ordinalPosition: parameter.ordinal
                        )
                    }
                if !parameters.isEmpty {
                    parametersByObject[objectName] = parameters
                }
            } catch let sqlError as SQLServerError {
                if case .connectionClosed = sqlError {
                    throw MSSQLSessionError.connectionClosed
                }
                logger.warning("MSSQL loadParameters failed for \(schemaName).\(objectName): \(sqlError.description)")
            } catch {
                logger.warning("MSSQL loadParameters failed for \(schemaName).\(objectName): \(error.localizedDescription)")
            }
        }
        logger.info("MSSQL loadParameters for schema \(schemaName) finished with \(parametersByObject.count) populated objects")
        return parametersByObject
    }

    private func loadPrimaryKeyColumns(schema: String) async throws -> [String: Set<String>] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let constraints: [KeyConstraintMetadata]
        do {
            constraints = try await connection.listPrimaryKeys(database: currentDatabase, schema: schema, table: nil)
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        var map: [String: Set<String>] = [:]
        for constraint in constraints {
            if constraint.table.hasPrefix("meta_client_") { continue }
            var set = map[constraint.table] ?? []
            for column in constraint.columns {
                set.insert(column.column)
            }
            map[constraint.table] = set
        }
        return map
    }

    private func loadTableColumns(schema: String, table: String) async throws -> [TableStructureDetails.Column] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let metadata: [ColumnMetadata]
        do {
            metadata = try await connection.listColumns(database: currentDatabase, schema: schema, table: table)
        } catch let sqlError as SQLServerError {
            if case .connectionClosed = sqlError {
                throw MSSQLSessionError.connectionClosed
            }
            throw DatabaseError.queryError(sqlError.description)
        } catch {
            throw DatabaseError.queryError(error.localizedDescription)
        }

        return metadata.sorted { $0.ordinalPosition < $1.ordinalPosition }.map { column in
            let formattedType = MSSQLSession.formatTypeName(
                base: column.typeName,
                maxLength: column.maxLength,
                precision: column.precision.map { String($0) },
                scale: column.scale.map { String($0) }
            )
            return TableStructureDetails.Column(
                name: column.name,
                dataType: formattedType,
                isNullable: column.isNullable,
                defaultValue: column.defaultDefinition?.trimmingCharacters(in: .whitespacesAndNewlines),
                generatedExpression: column.computedDefinition?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private func loadPrimaryKey(schema: String, table: String) async throws -> TableStructureDetails.PrimaryKey? {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let constraints = try await connection.listPrimaryKeys(database: currentDatabase, schema: schema, table: table)
        guard let primary = constraints.first else { return nil }
        let columns = primary.columns.sorted { $0.ordinal < $1.ordinal }.map { $0.column }
        return TableStructureDetails.PrimaryKey(name: primary.name, columns: columns)
    }

    private func loadIndexes(schema: String, table: String) async throws -> [TableStructureDetails.Index] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let metadata = try await connection.listIndexes(database: currentDatabase, schema: schema, table: table)
        let filtered = metadata.filter { !$0.isPrimaryKey && !$0.isUniqueConstraint }
        return filtered.map { index in
            let columns = index.columns
                .filter { !$0.isIncluded }
                .sorted { $0.ordinal < $1.ordinal }
                .enumerated()
                .map { position, column in
                    TableStructureDetails.Index.Column(
                        name: column.column,
                        position: position + 1,
                        sortOrder: column.isDescending ? .descending : .ascending
                    )
                }
            return TableStructureDetails.Index(
                name: index.name,
                columns: columns,
                isUnique: index.isUnique,
                filterCondition: index.filterDefinition?.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadUniqueConstraints(schema: String, table: String) async throws -> [TableStructureDetails.UniqueConstraint] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let constraints = try await connection.listUniqueConstraints(database: currentDatabase, schema: schema, table: table)
        return constraints.map { constraint in
            let columns = constraint.columns.sorted { $0.ordinal < $1.ordinal }.map { $0.column }
            return TableStructureDetails.UniqueConstraint(name: constraint.name, columns: columns)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadForeignKeys(schema: String, table: String) async throws -> [TableStructureDetails.ForeignKey] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let metadata = try await connection.listForeignKeys(database: currentDatabase, schema: schema, table: table)
        return metadata.map { foreignKey in
            let sortedColumns = foreignKey.columns.sorted { $0.ordinal < $1.ordinal }
            let columns = sortedColumns.map { $0.parentColumn }
            let referencedColumns = sortedColumns.map { $0.referencedColumn }
            return TableStructureDetails.ForeignKey(
                name: foreignKey.name,
                columns: columns,
                referencedSchema: foreignKey.referencedSchema,
                referencedTable: foreignKey.referencedTable,
                referencedColumns: referencedColumns,
                onUpdate: foreignKey.updateAction,
                onDelete: foreignKey.deleteAction
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadDependencies(schema: String, table: String) async throws -> [TableStructureDetails.Dependency] {
        try await ensureDefaultDatabaseContext()
        let currentDatabase = await resolvedCurrentDatabase()
        let dependencies = try await connection.listDependencies(database: currentDatabase, schema: schema, object: table)
        var results: [TableStructureDetails.Dependency] = []

        for dependency in dependencies {
            let referencingSchema = dependency.referencingSchema
            let referencingObject = dependency.referencingObject
            guard dependency.referencingType.uppercased().contains("TABLE") else { continue }
            do {
                let foreignKeys = try await connection.listForeignKeys(database: currentDatabase, schema: referencingSchema, table: referencingObject)
                for foreignKey in foreignKeys {
                    guard foreignKey.referencedSchema.caseInsensitiveCompare(schema) == .orderedSame,
                          foreignKey.referencedTable.caseInsensitiveCompare(table) == .orderedSame else { continue }
                    let sortedColumns = foreignKey.columns.sorted { $0.ordinal < $1.ordinal }
                    let baseColumns = sortedColumns.map { $0.parentColumn }
                    let referencedColumns = sortedColumns.map { $0.referencedColumn }
                    let qualifiedTable = referencingSchema.caseInsensitiveCompare(schema) == .orderedSame ? referencingObject : "\(referencingSchema).\(referencingObject)"
                    results.append(
                        TableStructureDetails.Dependency(
                            name: foreignKey.name,
                            baseColumns: baseColumns,
                            referencedTable: qualifiedTable,
                            referencedColumns: referencedColumns,
                            onUpdate: foreignKey.updateAction,
                            onDelete: foreignKey.deleteAction
                        )
                    )
                }
            } catch let sqlError as SQLServerError {
                if case .connectionClosed = sqlError {
                    throw MSSQLSessionError.connectionClosed
                }
                logger.warning("MSSQL loadDependencies failed for referencing object \(referencingSchema).\(referencingObject): \(sqlError.description)")
            } catch {
                logger.warning("MSSQL loadDependencies failed for referencing object \(referencingSchema).\(referencingObject): \(error.localizedDescription)")
            }
        }

        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
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

    private static func displayType(for column: SQLServerColumnDescription) -> String {
        switch column.type {
        case .nvarchar, .nchar, .varchar, .char:
            if column.length == -1 {
                return "\(column.type)(MAX)"
            }
            let length = normalizedLength(for: column) ?? column.length
            return "\(column.type)(\(length))"
        case .decimal, .numeric:
            let precision = column.precision ?? 0
            let scale = column.scale ?? 0
            return "\(column.type)(\(precision), \(scale))"
        default:
            return String(describing: column.type)
        }
    }

    private static func normalizedLength(for column: SQLServerColumnDescription) -> Int? {
        guard column.length > 0 else { return nil }
        switch column.type {
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
        try await ensureDefaultDatabaseContext()
        logger.info("MSSQL loadSchemaInfo starting for schema \(schemaName)")
        let columnMap = try await buildColumnMapUsingMetadataClient(schemaName: schemaName)

        let currentDatabase = await resolvedCurrentDatabase()
        let tableMetadata = try await connection.listTables(database: currentDatabase, schema: schemaName)
            .filter { !$0.isSystemObject && !$0.name.hasPrefix("meta_client_") }
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(tableMetadata.count) tables/views")

        let functionMetadata = try await connection.listFunctions(database: currentDatabase, schema: schemaName)
            .filter { !$0.isSystemObject && !$0.name.hasPrefix("meta_client_") }
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(functionMetadata.count) functions")

        let procedureMetadata = try await connection.listProcedures(database: currentDatabase, schema: schemaName)
            .filter { !$0.isSystemObject && !$0.name.hasPrefix("meta_client_") }
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(procedureMetadata.count) procedures")

        let triggerMetadata = try await connection.listTriggers(database: currentDatabase, schema: schemaName)
            .filter { !$0.name.hasPrefix("meta_client_") && !$0.table.hasPrefix("meta_client_") }
        logger.info("MSSQL loadSchemaInfo schema \(schemaName) discovered \(triggerMetadata.count) triggers")

        let routineNames = Set(functionMetadata.map(\.name) + procedureMetadata.map(\.name))
        let parameterMap = try await loadParameters(schemaName: schemaName, objectNames: Array(routineNames), database: currentDatabase)

        let totalObjects = max(tableMetadata.count + functionMetadata.count + procedureMetadata.count + triggerMetadata.count, 1)
        var processed = 0
        var objects: [SchemaObjectInfo] = []

        for table in tableMetadata {
            let type: SchemaObjectInfo.ObjectType = table.type.uppercased().contains("VIEW") ? .view : .table
            if let progress {
                await progress(type, processed, totalObjects)
            }
            processed += 1
            let columns = columnMap[table.name] ?? []
            objects.append(
                SchemaObjectInfo(
                    name: table.name,
                    schema: schemaName,
                    type: type,
                    columns: columns,
                    parameters: []
                )
            )
        }

        if let progress {
            await progress(.function, processed, totalObjects)
        }
        for function in functionMetadata {
            let name = function.name
            processed += 1
            if let progress {
                await progress(.function, processed, totalObjects)
            }
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: .function,
                    parameters: parameterMap[name] ?? []
                )
            )
        }

        if let progress {
            await progress(.procedure, processed, totalObjects)
        }
        for procedure in procedureMetadata {
            let name = procedure.name
            processed += 1
            if let progress {
                await progress(.procedure, processed, totalObjects)
            }
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: .procedure,
                    parameters: parameterMap[name] ?? []
                )
            )
        }

        if let progress {
            await progress(.trigger, processed, totalObjects)
        }
        for trigger in triggerMetadata {
            let name = trigger.name
            let parentName = trigger.table
            processed += 1
            if let progress {
                await progress(.trigger, processed, totalObjects)
            }
            var actionParts: [String] = []
            actionParts.append(trigger.isInsteadOf ? "INSTEAD OF" : "AFTER")
            if trigger.isDisabled {
                actionParts.append("DISABLED")
            }
            let action = actionParts.joined(separator: " ")
            let tableFull = "\(schemaName).\(parentName)"
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: .trigger,
                    columns: [],
                    parameters: [],
                    triggerAction: action.isEmpty ? nil : action,
                    triggerTable: tableFull
                )
            )
        }

        logger.info("MSSQL loadSchemaInfo completed for schema \(schemaName) with \(objects.count) objects")
        return SchemaInfo(name: schemaName, objects: objects)
    }
}

enum MSSQLSessionError: Error {
    case connectionClosed
}

extension MSSQLSessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .connectionClosed:
            return "SQL Server connection closed"
        }
    }
}

private struct MSSQLRow {
    let row: TDSRow
    let formatter: MSSQLCellFormatter
    let metadata: [TDSTokens.ColMetadataToken.ColumnData]
    private let columnNameLookup: [String: String]

    init(row: TDSRow, formatter: MSSQLCellFormatter) {
        self.row = row
        self.formatter = formatter
        self.metadata = MSSQLSession.metadataColumns(from: row.columnMetadata)
        var lookup: [String: String] = [:]
        lookup.reserveCapacity(metadata.count)
        for column in metadata {
            let lowercased = column.colName.lowercased()
            if lookup[lowercased] == nil {
                lookup[lowercased] = column.colName
            }
        }
        self.columnNameLookup = lookup
    }

    func string(_ column: String) -> String? {
        guard let data = data(for: column), data.value != nil else { return nil }
        return formatter.stringValue(for: data)
    }

    func data(for column: String) -> TDSData? {
        guard let resolved = resolveColumnName(column) else { return nil }
        return row.column(resolved)
    }

    private func resolveColumnName(_ name: String) -> String? {
        columnNameLookup[name.lowercased()]
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

private actor MSSQLDatabaseContext {
    private var active: String?

    func needsSwitch(to target: String) -> Bool {
        let normalized = target.lowercased()
        return active?.lowercased() != normalized
    }

    func setActive(_ target: String) {
        active = target
    }

    func reset() {
        active = nil
    }
}
