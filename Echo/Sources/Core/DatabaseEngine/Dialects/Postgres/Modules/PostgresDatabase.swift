import Foundation
import PostgresKit
import PostgresWire
import Logging
import os

typealias PostgresQueryResult = PostgresRowSequence

struct PostgresNIOFactory: DatabaseFactory {
    private let packageLogger = Logging.Logger(label: "dev.echodb.echo.postgres")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool = false,
        tlsMode: TLSMode = .prefer,
        sslRootCertPath: String? = nil,
        sslCertPath: String? = nil,
        sslKeyPath: String? = nil,
        mssqlEncryptionMode: MSSQLEncryptionMode = .optional,
        readOnlyIntent: Bool = false,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        guard authentication.method == .sqlPassword else {
            throw DatabaseError.authenticationFailed("Windows authentication is not supported for PostgreSQL")
        }
        let effectiveDatabase = (database?.isEmpty == false) ? database : "postgres"
        let databaseLabel = effectiveDatabase ?? "postgres"
        os.Logger.postgres.info("Connecting to PostgreSQL at \(host):\(port)/\(databaseLabel)")

        let wireSslMode: PostgresSSLMode = switch tlsMode {
        case .disable: .disable
        case .allow: .allow
        case .prefer: .prefer
        case .require: .require
        case .verifyCA: .verifyCA
        case .verifyFull: .verifyFull
        }

        let configuration = PostgresConfiguration(
            host: host,
            port: port,
            database: effectiveDatabase ?? "postgres",
            username: authentication.username,
            password: authentication.password,
            sslMode: wireSslMode,
            sslRootCertPath: sslRootCertPath,
            sslCertPath: sslCertPath,
            sslKeyPath: sslKeyPath,
            applicationName: "Echo",
            connectTimeout: connectTimeoutSeconds
        )

        let serverConnection = try await PostgresServerConnection.connect(
            configuration: configuration,
            logger: packageLogger
        )

        return PostgresSession(
            client: serverConnection.primaryClient,
            serverConnection: serverConnection,
            packageLogger: packageLogger
        )
    }
}

extension PostgresSession: @unchecked Sendable {}

final class PostgresSession: DatabaseSession {
    let client: PostgresKit.PostgresClient
    let serverConnection: PostgresServerConnection?
    let packageLogger: Logging.Logger

    init(client: PostgresKit.PostgresClient, serverConnection: PostgresServerConnection? = nil, packageLogger: Logging.Logger) {
        self.client = client
        self.serverConnection = serverConnection
        self.packageLogger = packageLogger
    }

    func close() async {
        if let serverConnection {
            await serverConnection.closeAll()
        } else {
            client.close()
        }
    }

    func isSuperuser() async throws -> Bool {
        return try await client.metadata.checkSuperuser()
    }

    func fetchPermissions() async throws -> (any DatabasePermissionProviding)? {
        let perms = try await client.security.currentPermissions()
        return PostgresPermissionAdapter(permissions: perms)
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        guard let serverConnection else { return self }
        let dbClient = try await serverConnection.client(for: database)
        if dbClient === client { return self }
        return PostgresSession(client: dbClient, serverConnection: serverConnection, packageLogger: packageLogger)
    }

    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        PostgresActivityMonitorWrapper(client.activity)
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .postgresql) {
            return try await executeSimpleQuery(sql)
        }
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: nil)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if QueryStatementClassifier.isLikelyMessageOnlyStatement(sql, databaseType: .postgresql) {
            return try await executeSimpleQuery(sql)
        }
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: executionMode)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        do {
            let result = try await client.simpleQueryResult(sql)

            var columns: [ColumnInfo] = []
            var rows: [[String?]] = []
            rows.reserveCapacity(512)

            let formatter = PostgresCellFormatter()

            for row in result.rows {
                if columns.isEmpty {
                    let wireColumns = PostgresRowExtractor.columns(from: row)
                    columns.reserveCapacity(wireColumns.count)
                    for col in wireColumns {
                        columns.append(ColumnInfo(
                            name: col.name,
                            dataType: col.dataType,
                            isPrimaryKey: col.isPrimaryKey,
                            isNullable: col.isNullable,
                            maxLength: col.maxLength
                        ))
                    }
                }

                let (_, preview) = PostgresRowExtractor.extractRow(
                    from: row,
                    formatPreview: true,
                    formatter: formatter
                )
                rows.append(preview ?? [])
            }

            let resolvedColumns = columns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : columns

            return QueryResultSet(
                columns: resolvedColumns,
                rows: rows,
                commandTag: rawCommandTag(from: result.metadata)
            )
        } catch {
            throw normalizeError(error, contextSQL: sql)
        }
    }

    private func rawCommandTag(from metadata: WireQueryMetadata) -> String {
        var segments = [metadata.command]
        if let oid = metadata.oid {
            segments.append(String(oid))
        }
        if let rows = metadata.rows {
            segments.append(String(rows))
        }
        return segments.joined(separator: " ")
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let result = try await client.simpleQuery(sql)
        var count = 0
        for try await _ in result { count += 1 }
        return count
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        try await client.admin.renameTable(oldName: oldName, newName: newName, schema: schema)
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        _ = try await client.admin.dropTable(name: name, ifExists: ifExists, cascade: false, schema: schema)
    }

    func truncateTable(schema: String?, name: String) async throws {
        _ = try await client.bulk.truncate(table: name, cascade: false, restartIdentity: false, schema: schema)
    }

    func listDatabases() async throws -> [String] {
        return try await client.metadata.listDatabases()
    }

    func listSchemas() async throws -> [String] {
        return try await client.metadata.listSchemas().map { $0.name }
    }

    func listExtensions() async throws -> [SchemaObjectInfo] {
        let extensions = try await client.metadata.listExtensions()
        return extensions.map { ext in
            SchemaObjectInfo(
                name: ext.name,
                schema: ext.schema,
                type: .extension,
                comment: "Version: \(ext.version)"
            )
        }
    }

    func listExtensionObjects(extensionName: String) async throws -> [ExtensionObjectInfo] {
        // TODO: Add listExtensionObjects to postgres-wire .metadata
        return []
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        return try await loadSchemaInfo(schemaName, progress: nil).objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"
        let cols = try await client.metadata.listColumns(schema: schema, table: tableName)
        return cols.map { ColumnInfo(name: $0.name, dataType: $0.dataType, isPrimaryKey: false, isNullable: $0.isNullable, maxLength: nil) }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {

        let columnList = try await client.metadata.listColumns(schema: schema, table: table)
        let columns = columnList.map {
            TableStructureDetails.Column(
                name: $0.name, dataType: $0.dataType, isNullable: $0.isNullable,
                defaultValue: $0.defaultValue, generatedExpression: nil,
                isIdentity: $0.isIdentity, identityGeneration: $0.identityGeneration,
                collation: $0.collation
            )
        }

        let primaryKey: TableStructureDetails.PrimaryKey?
        if let p = try? await client.metadata.primaryKey(schema: schema, table: table) {
            primaryKey = TableStructureDetails.PrimaryKey(name: p.name, columns: p.columns, isDeferrable: p.isDeferrable, isInitiallyDeferred: p.isInitiallyDeferred)
        } else {
            primaryKey = nil
        }

        let indexList = try await client.metadata.listIndexes(schema: schema, table: table)
        let indexes = indexList.map { i in
            let cols = i.columns.enumerated().map { (pos, c) in
                TableStructureDetails.Index.Column(name: c.name, position: pos + 1, sortOrder: c.isDescending ? .descending : .ascending, isIncluded: c.isIncluded)
            }
            return TableStructureDetails.Index(name: i.name, columns: cols, isUnique: i.isUnique, filterCondition: i.predicate, indexType: i.indexType)
        }

        let fkList = try await client.metadata.foreignKeys(schema: schema, table: table)
        let foreignKeys = fkList.map { fk in
            TableStructureDetails.ForeignKey(name: fk.name, columns: fk.columns, referencedSchema: fk.referencedSchema, referencedTable: fk.referencedTable, referencedColumns: fk.referencedColumns, onUpdate: fk.onUpdate, onDelete: fk.onDelete, isDeferrable: fk.isDeferrable, isInitiallyDeferred: fk.isInitiallyDeferred)
        }

        let uniqueList = try await client.metadata.uniqueConstraints(schema: schema, table: table)
        let uniqueConstraints = uniqueList.map {
            TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns, isDeferrable: $0.isDeferrable, isInitiallyDeferred: $0.isInitiallyDeferred)
        }

        let depList = try await client.metadata.dependencies(schema: schema, table: table)
        let dependencies = depList.map { d in
            TableStructureDetails.Dependency(name: d.name, baseColumns: d.referencingColumns, referencedTable: d.sourceTable, referencedColumns: d.referencedColumns, onUpdate: d.onUpdate, onDelete: d.onDelete)
        }

        let checkList = try await client.metadata.checkConstraints(schema: schema, table: table)
        let checkConstraints = checkList.map {
            TableStructureDetails.CheckConstraint(name: $0.name, expression: $0.expression)
        }

        let pgProps = try await client.metadata.tableProperties(schema: schema, table: table)
        let tableProperties = TableStructureDetails.TableProperties(
            fillfactor: pgProps.fillfactor,
            toastTupleTarget: pgProps.toastTupleTarget,
            autovacuumEnabled: pgProps.autovacuumEnabled,
            parallelWorkers: pgProps.parallelWorkers,
            tablespace: pgProps.tablespace
        )

        return TableStructureDetails(columns: columns, primaryKey: primaryKey, indexes: indexes, uniqueConstraints: uniqueConstraints, foreignKeys: foreignKeys, dependencies: dependencies, checkConstraints: checkConstraints, tableProperties: tableProperties)
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType, database: String? = nil) async throws -> String {
        // If a specific database is requested, delegate to a session connected to that database
        if let database {
            let targetSession = try await sessionForDatabase(database)
            if let pgSession = targetSession as? PostgresSession {
                return try await pgSession.getObjectDefinition(
                    objectName: objectName,
                    schemaName: schemaName,
                    objectType: objectType
                )
            }
        }

        switch objectType {
        case .table, .materializedView:
            let columns = try await getTableSchema(objectName, schemaName: schemaName)
            guard !columns.isEmpty else {
                return "-- No columns available for \(schemaName).\(objectName)"
            }

            let columnLines = columns.map { column -> String in
                var parts = ["\"\(column.name)\" \(column.dataType)"]
                if let maxLength = column.maxLength, maxLength > 0 {
                    parts[0] += "(\(maxLength))"
                }
                if !column.isNullable {
                    parts.append("NOT NULL")
                }
                if column.isPrimaryKey {
                    parts.append("PRIMARY KEY")
                }
                return parts.joined(separator: " ")
            }

            let keyword = objectType == .table ? "TABLE" : "MATERIALIZED VIEW"
            return """
            CREATE \(keyword) "\(schemaName)"."\(objectName)" (
            \(columnLines.joined(separator: ",\n"))
            );
            """

        case .view:
            if let queryBody = try await client.metadata.viewDefinition(schema: schemaName, view: objectName) {
                return "CREATE VIEW \"\(schemaName)\".\"\(objectName)\" AS\n\(queryBody)"
            }
            return "-- View definition unavailable"

        case .function, .procedure:
            if let definition = try await client.metadata.functionDefinition(schema: schemaName, name: objectName) {
                return definition
            }
            let descriptor = objectType == .function ? "Function" : "Procedure"
            return "-- \(descriptor) definition unavailable"

        case .trigger:
            if let definition = try await client.metadata.triggerDefinition(schema: schemaName, name: objectName) {
                return definition
            }
            return "-- Trigger definition unavailable"

        case .extension:
            return "-- Extension definition unavailable"

        case .sequence:
            return "-- Sequence definition: use \\d \"\(schemaName)\".\"\(objectName)\" in psql"

        case .type:
            return "-- Type definition unavailable"

        case .synonym:
            return "-- Synonyms are not available in PostgreSQL"
        }
    }
}

extension PostgresSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let summary = try await client.metadata.schemaSummary(schema: schemaName) { type, current, total in
            if let progress {
                let mapped: SchemaObjectInfo.ObjectType
                switch type {
                case .table: mapped = .table
                case .view: mapped = .view
                case .materializedView: mapped = .materializedView
                case .function: mapped = .function
                case .procedure: mapped = .procedure
                case .trigger: mapped = .trigger
                }
                await progress(mapped, current, total)
            }
        }

        var objects: [SchemaObjectInfo] = []
        for o in summary.objects {
            let columns: [ColumnInfo] = o.columns.map { d in
                let fk: ColumnInfo.ForeignKeyReference? = d.foreignKey.map { ref in
                    ColumnInfo.ForeignKeyReference(
                        constraintName: ref.constraintName,
                        referencedSchema: ref.referencedSchema,
                        referencedTable: ref.referencedTable,
                        referencedColumn: ref.referencedColumn
                    )
                }
                return ColumnInfo(name: d.name, dataType: d.dataType, isPrimaryKey: d.isPrimaryKey, isNullable: d.isNullable, maxLength: d.maxLength, foreignKey: fk)
            }

            let mapped: SchemaObjectInfo.ObjectType
            switch o.type {
            case .table: mapped = .table
            case .view: mapped = .view
            case .materializedView: mapped = .materializedView
            case .function: mapped = .function
            case .procedure: mapped = .procedure
            case .trigger: mapped = .trigger
            }

            objects.append(SchemaObjectInfo(
                name: o.name,
                schema: summary.schema,
                type: mapped,
                columns: columns,
                triggerAction: o.triggerAction,
                triggerTable: o.triggerTable
            ))
        }

        // Sequences via typed API
        do {
            let sequences = try await client.metadata.listSequences(schema: schemaName)
            for seq in sequences {
                objects.append(SchemaObjectInfo(name: seq.name, schema: schemaName, type: .sequence))
            }
        } catch {
            // Sequences are best-effort
        }

        // User-defined types via typed API
        do {
            let types = try await client.types.listTypes(schema: schemaName)
            for pgType in types {
                objects.append(SchemaObjectInfo(name: pgType.name, schema: schemaName, type: .type, comment: pgType.kind))
            }
        } catch {
            // Types are best-effort
        }

        return SchemaInfo(name: schemaName, objects: objects)
    }

    func rebuildIndex(schema: String, table: String, index: String) async throws -> DatabaseMaintenanceResult {
        try await client.maintenance.reindex(table: table)
        return DatabaseMaintenanceResult(operation: "Reindex", messages: ["Index rebuilt successfully."], succeeded: true)
    }

    func rebuildIndexes(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        _ = try await client.maintenance.reindex(table: table)
        return DatabaseMaintenanceResult(operation: "Reindex", messages: ["Table indexes rebuilt successfully."], succeeded: true)
    }

    func vacuumTable(schema: String, table: String, full: Bool, analyze: Bool) async throws {
        try await client.maintenance.vacuum(schema: schema, table: table, analyze: analyze, full: full)
    }

    func analyzeTable(schema: String, table: String) async throws {
        try await client.maintenance.analyze(schema: schema, table: table)
    }

    func reindexTable(schema: String, table: String) async throws {
        try await client.maintenance.reindex(schema: schema, table: table)
    }

    func updateTableStatistics(schema: String, table: String) async throws -> DatabaseMaintenanceResult {
        try await analyzeTable(schema: schema, table: table)
        return DatabaseMaintenanceResult(operation: "Analyze", messages: ["Statistics updated successfully."], succeeded: true)
    }

    func checkDatabaseIntegrity() async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Integrity checks are not supported for PostgreSQL")
    }

    func shrinkDatabase() async throws -> DatabaseMaintenanceResult {
        throw DatabaseError.queryError("Shrink is not supported for PostgreSQL")
    }

    func listAvailableExtensions() async throws -> [AvailableExtensionInfo] {
        // TODO: Add listAvailableExtensions to postgres-wire .metadata
        return []
    }

    func installExtension(name: String, schema: String?, version: String?, cascade: Bool) async throws {
        // Simple CREATE EXTENSION for now. 
        // Note: version selection not yet in Driver's createExtension, will need update.
        _ = try await client.maintenance.createExtension(name, ifNotExists: true, schema: schema, version: version, cascade: cascade)
    }

    func updateExtension(name: String, to version: String?) async throws {
        _ = try await client.maintenance.updateExtension(name, to: version)
    }
}
