import Foundation
import PostgresKit
import PostgresWire
import Logging

typealias PostgresQueryResult = PostgresRowSequence

struct PostgresNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.postgres")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        guard authentication.method == .sqlPassword else {
            throw DatabaseError.authenticationFailed("Windows authentication is not supported for PostgreSQL")
        }
        let effectiveDatabase = (database?.isEmpty == false) ? database : "postgres"
        let databaseLabel = effectiveDatabase ?? "postgres"
        logger.info("Connecting to PostgreSQL at \(host):\(port)/\(databaseLabel)")

        let configuration = PostgresConfiguration(
            host: host,
            port: port,
            database: effectiveDatabase ?? "postgres",
            username: authentication.username,
            password: authentication.password,
            useTLS: tls,
            applicationName: "Echo",
            connectTimeout: connectTimeoutSeconds
        )

        let client = try await PostgresDatabaseClient.connect(configuration: configuration, logger: logger)

        return PostgresSession(client: client, logger: logger)
    }
}

extension PostgresSession: @unchecked Sendable {}

final class PostgresSession: DatabaseSession {
    let client: PostgresDatabaseClient
    let logger: Logger

    init(client: PostgresDatabaseClient, logger: Logger) {
        self.client = client
        self.logger = logger
    }

    func close() async {
        client.close()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        try await simpleQuery(sql, progressHandler: nil)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: nil)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        if let progressHandler {
            let sanitized = sanitizeSQL(sql)
            return try await streamQuery(sanitizedSQL: sanitized, progressHandler: progressHandler, modeOverride: executionMode)
        } else {
            return try await executeSimpleQuery(sql)
        }
    }

    private func executeSimpleQuery(_ sql: String) async throws -> QueryResultSet {
        do {
            let result = try await client.simpleQuery(sql)

            var columns: [ColumnInfo] = []
            var rows: [[String?]] = []
            rows.reserveCapacity(512)

            let formatterContext = CellFormatterContext()

            for try await row in result {
                if columns.isEmpty {
                    for cell in row {
                        columns.append(ColumnInfo(
                            name: cell.columnName,
                            dataType: "\(cell.dataType)",
                            isPrimaryKey: false,
                            isNullable: true,
                            maxLength: nil
                        ))
                    }
                }

                var rowValues: [String?] = []
                rowValues.reserveCapacity(row.count)
                for cell in row {
                    rowValues.append(formatterContext.stringValue(for: cell))
                }
                rows.append(rowValues)
            }

            let resolvedColumns = columns.isEmpty
                ? [ColumnInfo(name: "result", dataType: "text")]
                : columns

            return QueryResultSet(
                columns: resolvedColumns,
                rows: rows
            )
        } catch {
            throw normalizeError(error, contextSQL: sql)
        }
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

    func listDatabases() async throws -> [String] {
        let meta = PostgresMetadata()
        return try await meta.listDatabases(using: client)
    }

    func listSchemas() async throws -> [String] {
        let meta = PostgresMetadata()
        return try await meta.listSchemas(using: client)
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        return try await loadSchemaInfo(schemaName, progress: nil).objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"
        let meta = PostgresMetadata()
        let cols = try await meta.listColumns(using: client, schema: schema, table: tableName)
        return cols.map { ColumnInfo(name: $0.name, dataType: $0.dataType, isPrimaryKey: false, isNullable: $0.isNullable, maxLength: nil) }
    }

    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails {
        let meta = PostgresMetadata()
        async let cols: [TableStructureDetails.Column] = {
            let list = try? await meta.listColumns(using: client, schema: schema, table: table)
            return (list ?? []).map { TableStructureDetails.Column(name: $0.name, dataType: $0.dataType, isNullable: $0.isNullable, defaultValue: $0.defaultValue, generatedExpression: nil) }
        }()
        async let pk: TableStructureDetails.PrimaryKey? = {
            if let p = try? await meta.primaryKey(using: client, schema: schema, table: table) {
                return TableStructureDetails.PrimaryKey(name: p.name, columns: p.columns)
            }
            return nil
        }()
        async let idx: [TableStructureDetails.Index] = {
            let list = try? await meta.listIndexes(using: client, schema: schema, table: table)
            return (list ?? []).map { i in
                let columns = i.columns.enumerated().map { (pos, c) in
                    TableStructureDetails.Index.Column(name: c.name, position: pos + 1, sortOrder: c.isDescending ? .descending : .ascending)
                }
                return TableStructureDetails.Index(name: i.name, columns: columns, isUnique: i.isUnique, filterCondition: i.predicate)
            }
        }()
        async let fks: [TableStructureDetails.ForeignKey] = {
            let list = try? await meta.foreignKeys(using: client, schema: schema, table: table)
            return (list ?? []).map { fk in
                TableStructureDetails.ForeignKey(name: fk.name, columns: fk.columns, referencedSchema: fk.referencedSchema, referencedTable: fk.referencedTable, referencedColumns: fk.referencedColumns, onUpdate: fk.onUpdate, onDelete: fk.onDelete)
            }
        }()
        async let uniques: [TableStructureDetails.UniqueConstraint] = {
            let list = try? await meta.uniqueConstraints(using: client, schema: schema, table: table)
            return (list ?? []).map { TableStructureDetails.UniqueConstraint(name: $0.name, columns: $0.columns) }
        }()
        async let deps: [TableStructureDetails.Dependency] = {
            let list = try? await meta.dependencies(using: client, schema: schema, table: table)
            return (list ?? []).map { d in
                TableStructureDetails.Dependency(name: d.name, baseColumns: d.referencingColumns, referencedTable: d.sourceTable, referencedColumns: d.referencedColumns, onUpdate: d.onUpdate, onDelete: d.onDelete)
            }
        }()
        let (columns, primaryKey, indexes, foreignKeys, uniqueConstraints, dependencies) = await (cols, pk, idx, fks, uniques, deps)
        return TableStructureDetails(columns: columns, primaryKey: primaryKey, indexes: indexes, uniqueConstraints: uniqueConstraints, foreignKeys: foreignKeys, dependencies: dependencies)
    }

    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String {
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
            let meta = PostgresMetadata()
            if let definition = try await meta.viewDefinition(using: client, schema: schemaName, view: objectName) {
                return definition
            }
            return "-- View definition unavailable"

        case .function, .procedure:
            let meta = PostgresMetadata()
            if let definition = try await meta.functionDefinition(using: client, schema: schemaName, name: objectName) {
                return definition
            }
            let descriptor = objectType == .function ? "Function" : "Procedure"
            return "-- \(descriptor) definition unavailable"

        case .trigger:
            let meta = PostgresMetadata()
            if let definition = try await meta.triggerDefinition(using: client, schema: schemaName, name: objectName) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }
}

extension PostgresSession: DatabaseMetadataSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo {
        let meta = PostgresMetadata()
        let summary = try await meta.schemaSummary(using: client, schema: schemaName) { type, current, total in
            if let progress {
                let mapped: SchemaObjectInfo.ObjectType
                switch type {
                case .table: mapped = .table
                case .view: mapped = .view
                case .materializedView: mapped = .materializedView
                case .function: mapped = .function
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

        return SchemaInfo(name: schemaName, objects: objects)
    }
}
