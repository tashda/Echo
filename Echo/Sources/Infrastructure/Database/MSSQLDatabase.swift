import Foundation
import NIO
import SQLServerKit
import Logging

// MARK: - Factory

struct MSSQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mssql")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession {
        let resolvedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines)
        let loginDatabase = resolvedDatabase?.isEmpty == false ? resolvedDatabase! : "master"
        let metadataTimeout: TimeInterval = 30
        let metadataConfiguration = SQLServerMetadataClient.Configuration(
            includeSystemSchemas: false,
            enableColumnCache: true,
            includeRoutineDefinitions: false,
            includeTriggerDefinitions: true,
            commandTimeout: metadataTimeout,
            extractParameterDefaults: false,
            preferStoredProcedureColumns: false
        )
        // Convert Echo authentication to SQLServerKit authentication
        let sqlServerAuth: TDSAuthentication

        switch authentication.method {
        case .sqlPassword:
            guard let password = authentication.password else {
                throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
            }
            sqlServerAuth = TDSAuthentication.sqlPassword(
                username: authentication.username,
                password: password
            )
        default:
            throw DatabaseError.authenticationFailed("Only SQL password authentication is supported for SQL Server")
        }

        let configuration = SQLServerClient.Configuration(
            hostname: host,
            port: port,
            login: .init(database: loginDatabase, authentication: sqlServerAuth),
            tlsConfiguration: tls ? .makeClientConfiguration() : nil,
            metadataConfiguration: metadataConfiguration
        )

        logger.info("Connecting to SQL Server at \(host):\(port)/\(loginDatabase)")

        // SQLServerClient.connect returns an EventLoopFuture, so we need to await it properly
        let client = try await withCheckedThrowingContinuation { continuation in
            SQLServerClient.connect(
                configuration: configuration,
                eventLoopGroupProvider: .shared(EchoEventLoopGroup.shared)
            ).whenComplete { result in
                switch result {
                case .success(let client):
                    continuation.resume(returning: client)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        // Wrap the SQLServerClient in an adapter that conforms to DatabaseSession
        return SQLServerSessionAdapter(
            client: client,
            database: resolvedDatabase?.isEmpty == false ? resolvedDatabase : nil
        )
    }
}

// MARK: - Session Adapter

/// Adapter to make SQLServerClient conform to Echo's DatabaseSession protocol
final class SQLServerSessionAdapter: DatabaseSession {
    private let client: SQLServerClient
    private let database: String?
    private let logger = Logger(label: "dk.tippr.echo.mssql.metadata")
    private let metadataTraceEnabled = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE"] == "1"
    private let metadataTracePath: String?
    private static let metadataTraceQueue = DispatchQueue(label: "dk.tippr.echo.mssql.metadata.trace")

    init(client: SQLServerClient, database: String?) {
        self.client = client
        self.database = database
        if metadataTraceEnabled {
            let envPath = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE_PATH"]
            metadataTracePath = envPath?.isEmpty == false ? envPath : "/tmp/echo-mssql-metadata-trace.log"
        } else {
            metadataTracePath = nil
        }
    }

    func close() async {
        do {
            try await client.shutdownGracefully().get()
        } catch {
            // Ignore shutdown errors; the app is shutting down the session.
        }
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        // Use SQLServerKit's query functionality
        let rows: [TDSRow] = try await client.query(sql)

        // Convert SQLServerKit result to Echo's QueryResultSet
        return try await convertSQLServerRowsToEcho(rows)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        return try await simpleQuery(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        return try await simpleQuery(sql)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let tables = try await client.listTables(
            database: database,
            schema: schema,
            includeComments: false
        )
        return tables.compactMap { table in
            if table.isSystemObject {
                return nil
            }
            let objectType: SchemaObjectInfo.ObjectType = table.isView ? .view : .table
            return SchemaObjectInfo(
                name: table.name,
                schema: table.schema,
                type: objectType,
                comment: table.comment
            )
        }
    }

    func listDatabases() async throws -> [String] {
        let databases = try await client.listDatabases()
        return databases.map(\.name)
    }

    func listSchemas() async throws -> [String] {
        let schemas = try await client.listSchemas(in: database)
        return schemas.map(\.name)
    }

    func loadDatabaseInfo(databaseName: String) async throws -> DatabaseInfo {
        let structure = try await metadataTimed("loadDatabaseStructure") {
            try await client.loadDatabaseStructure(database: databaseName, includeComments: false)
        }

        let schemaInfos = structure.schemas.map { schema -> SchemaInfo in
            var objects: [SchemaObjectInfo] = []
            objects.reserveCapacity(schema.tables.count + schema.views.count + schema.functions.count + schema.procedures.count + schema.triggers.count)

            for table in schema.tables {
                objects.append(makeTableObjectInfo(from: table, type: .table))
            }
            for view in schema.views {
                objects.append(makeTableObjectInfo(from: view, type: .view))
            }
            for routine in schema.functions {
                objects.append(makeRoutineObjectInfo(from: routine))
            }
            for routine in schema.procedures {
                objects.append(makeRoutineObjectInfo(from: routine))
            }
            for trigger in schema.triggers {
                objects.append(makeTriggerObjectInfo(from: trigger))
            }

            return SchemaInfo(name: schema.name, objects: objects)
        }

        return DatabaseInfo(name: databaseName, schemas: schemaInfos, schemaCount: schemaInfos.count)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        // Add ORDER BY and OFFSET/FETCH to the SQL for pagination
        let pagedSQL = """
        SELECT * FROM (
            SELECT *, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as row_num
            FROM (\(sql)) as subquery
        ) as paged
        WHERE row_num > \(offset) AND row_num <= \(offset + limit)
        """
        return try await simpleQuery(pagedSQL)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "dbo"
        let columns = try await client.listColumns(
            database: database,
            schema: schema,
            table: tableName,
            includeComments: false
        )
        let primaryKeys = try await client.listPrimaryKeysFromCatalog(
            database: database,
            schema: schema,
            table: tableName
        )
        let primaryKeyColumns = Set(primaryKeys.flatMap { $0.columns.map { $0.column.lowercased() } })

        return columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: primaryKeyColumns.contains(column.name.lowercased()),
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
        let objectTypeName: String
        switch objectType {
        case .table:
            objectTypeName = "U"
        case .view:
            objectTypeName = "V"
        case .procedure:
            objectTypeName = "P"
        case .function:
            objectTypeName = "FN"
        default:
            throw DatabaseError.queryError("Unsupported object type")
        }

        let query = """
        SELECT OBJECT_DEFINITION(OBJECT_ID('[\(schemaName)].[\(objectName)]', '\(objectTypeName)')) as definition
        """

        let rows: [TDSRow] = try await client.query(query)

        // Extract the definition from the result
        for row in rows {
            if let definition = row.column("definition")?.string {
                return definition
            }
        }

        throw DatabaseError.queryError("Object definition not found")
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        // Use SQLServerKit's execute method
        let result = try await client.execute(sql)
        return Int(result.rowCount ?? 0)
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        async let columnMetadataResult: [ColumnMetadata] = {
            (try? await client.listColumns(
                database: database,
                schema: schema,
                table: table
            )) ?? []
        }()

        async let primaryKeyMetadataResult: [KeyConstraintMetadata] = {
            (try? await client.listPrimaryKeys(
                database: database,
                schema: schema,
                table: table
            )) ?? []
        }()

        async let uniqueConstraintMetadataResult: [KeyConstraintMetadata] = {
            (try? await client.listUniqueConstraints(
                database: database,
                schema: schema,
                table: table
            )) ?? []
        }()

        async let foreignKeyMetadataResult: [ForeignKeyMetadata] = {
            (try? await client.listForeignKeys(
                database: database,
                schema: schema,
                table: table
            )) ?? []
        }()

        async let indexMetadataResult: [IndexMetadata] = {
            (try? await client.listIndexes(
                database: database,
                schema: schema,
                table: table
            )) ?? []
        }()

        let (columnMetadata, primaryKeyMetadata, uniqueConstraintMetadata, foreignKeyMetadata, indexMetadata) = await (
            columnMetadataResult,
            primaryKeyMetadataResult,
            uniqueConstraintMetadataResult,
            foreignKeyMetadataResult,
            indexMetadataResult
        )

        let columns = columnMetadata.map { column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.typeName,
                isNullable: column.isNullable,
                defaultValue: column.defaultDefinition,
                generatedExpression: column.computedDefinition
            )
        }

        let primaryKey = primaryKeyMetadata.first(where: { $0.type == .primaryKey }).map { pk in
            let ordered = pk.columns.sorted { $0.ordinal < $1.ordinal }.map(\.column)
            return TableStructureDetails.PrimaryKey(name: pk.name, columns: ordered)
        }

        let uniqueConstraints = uniqueConstraintMetadata.map { constraint in
            let ordered = constraint.columns.sorted { $0.ordinal < $1.ordinal }.map(\.column)
            return TableStructureDetails.UniqueConstraint(name: constraint.name, columns: ordered)
        }

        let foreignKeys = foreignKeyMetadata.map { fk in
            let ordered = fk.columns.sorted { $0.ordinal < $1.ordinal }
            return TableStructureDetails.ForeignKey(
                name: fk.name,
                columns: ordered.map(\.parentColumn),
                referencedSchema: fk.referencedSchema,
                referencedTable: fk.referencedTable,
                referencedColumns: ordered.map(\.referencedColumn),
                onUpdate: fk.updateAction,
                onDelete: fk.deleteAction
            )
        }

        let excludedIndexNames = Set(uniqueConstraintMetadata.map(\.name)).union(Set(primaryKeyMetadata.map(\.name)))
        let indexes = indexMetadata
            .filter { !excludedIndexNames.contains($0.name) }
            .map { index in
                let columns = index.columns
                    .sorted { $0.ordinal < $1.ordinal }
                    .map { column in
                        TableStructureDetails.Index.Column(
                            name: column.column,
                            position: column.ordinal,
                            sortOrder: column.isDescending ? .descending : .ascending
                        )
                    }
                return TableStructureDetails.Index(
                    name: index.name,
                    columns: columns,
                    isUnique: index.isUnique,
                    filterCondition: index.filterDefinition
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

    // MARK: - Helper Methods

    private func makeTableObjectInfo(from table: SQLServerTableStructure, type: SchemaObjectInfo.ObjectType) -> SchemaObjectInfo {
        let primaryKeyColumns = Set(table.primaryKey?.columns.map { $0.column.lowercased() } ?? [])
        let columns = table.columns.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: primaryKeyColumns.contains(column.name.lowercased()),
                isNullable: column.isNullable,
                maxLength: column.maxLength
            )
        }
        return SchemaObjectInfo(
            name: table.table.name,
            schema: table.table.schema,
            type: type,
            columns: columns,
            comment: table.table.comment
        )
    }

    private func makeRoutineObjectInfo(from routine: RoutineMetadata) -> SchemaObjectInfo {
        let type: SchemaObjectInfo.ObjectType = routine.type == .procedure ? .procedure : .function
        return SchemaObjectInfo(
            name: routine.name,
            schema: routine.schema,
            type: type,
            comment: routine.comment
        )
    }

    private func makeTriggerObjectInfo(from trigger: TriggerMetadata) -> SchemaObjectInfo {
        SchemaObjectInfo(
            name: trigger.name,
            schema: trigger.schema,
            type: .trigger,
            columns: [],
            triggerAction: trigger.isInsteadOf ? "INSTEAD OF" : "AFTER",
            triggerTable: trigger.table,
            comment: trigger.comment
        )
    }

    private func convertSQLServerRowsToEcho(_ rows: [TDSRow]) async throws -> QueryResultSet {
        // Convert SQLServerKit's TDSRow array to Echo's QueryResultSet
        var echoRows: [[String?]] = []
        var echoColumns: [ColumnInfo] = []

        // Extract column information from the first row
        if let firstRow = rows.first {
            echoColumns = firstRow.columnMetadata.map { column in
                ColumnInfo(
                    name: column.colName,
                    dataType: column.displayName,
                    isPrimaryKey: false,
                    isNullable: true,
                    maxLength: column.normalizedLength
                )
            }

            // Convert rows
            echoRows = rows.map { row in
                row.data.map { tdsData in
                    // Convert TDSData to String?
                    convertTDSDataToString(tdsData)
                }
            }
        }

        return QueryResultSet(
            columns: echoColumns,
            rows: echoRows,
            totalRowCount: echoRows.count,
            commandTag: nil
        )
    }

    private func convertTDSDataToString(_ data: TDSData?) -> String? {
        // Convert TDSData types to String?
        guard let data = data else {
            return nil
        }

        guard data.value != nil else {
            return nil
        }

        return data.description
    }

    private func metadataTrace(_ line: String) {
        guard metadataTraceEnabled else { return }
        logger.info("\(line)")
        print(line)
        guard let path = metadataTracePath else { return }
        let payload = line + "\n"
        guard let data = payload.data(using: .utf8) else { return }
        Self.metadataTraceQueue.async {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                if let handle = try? FileHandle(forWritingTo: url) {
                    defer { try? handle.close() }
                    handle.seekToEndOfFile()
                    try? handle.write(contentsOf: data)
                }
            } else {
                try? data.write(to: url, options: .atomic)
            }
        }
    }

    private func metadataTimed<T>(_ label: String, operation: () async throws -> T) async throws -> T {
        guard metadataTraceEnabled else {
            return try await operation()
        }
        let started = Date()
        let result = try await operation()
        let elapsed = String(format: "%.3f", Date().timeIntervalSince(started))
        metadataTrace("[MSSQLMetadataTrace] step \(label) \(elapsed)s")
        return result
    }
}

extension SQLServerSessionAdapter: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let schema = try await client.loadSchemaStructure(
            database: database,
            schema: schemaName,
            includeComments: false
        )

        var objects: [SchemaObjectInfo] = []
        objects.reserveCapacity(schema.tables.count + schema.views.count + schema.functions.count + schema.procedures.count + schema.triggers.count)

        for table in schema.tables {
            objects.append(makeTableObjectInfo(from: table, type: .table))
        }
        for view in schema.views {
            objects.append(makeTableObjectInfo(from: view, type: .view))
        }
        for routine in schema.functions {
            objects.append(makeRoutineObjectInfo(from: routine))
        }
        for routine in schema.procedures {
            objects.append(makeRoutineObjectInfo(from: routine))
        }
        for trigger in schema.triggers {
            objects.append(makeTriggerObjectInfo(from: trigger))
        }

        if let progress {
            let total = objects.count
            if total > 0 {
                var current = 0
                for object in objects {
                    current += 1
                    await progress(object.type, current, total)
                }
            }
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }
}

// Use the new SQLServerKit API for column info creation
private func makeColumnInfo(from metadata: [TDSTokens.ColMetadataToken.ColumnData]) -> [SQLServerKit.ColumnInfo] {
    return metadata.map { column in
        SQLServerKit.ColumnInfo(
            name: column.colName,
            dataType: column.displayName,
            isPrimaryKey: false, // Would need to be determined from constraints
            isNullable: (column.flags & 0x01) != 0,
            maxLength: column.normalizedLength
        )
    }
}
