import Foundation
import PostgresNIO
import Logging

typealias PostgresQueryResult = PostgresRowSequence

struct PostgresNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "fuzee.postgres.factory")

    func connect(host: String, port: Int, username: String, password: String?, database: String?, tls: Bool) async throws -> DatabaseSession {
        let databaseLabel = database ?? "(default)"
        logger.info("Connecting to PostgreSQL at \(host):\(port)/\(databaseLabel)")

        let configuration = PostgresClient.Configuration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: tls ? .require(.makeClientConfiguration()) : .disable
        )

        let client = PostgresClient(configuration: configuration, backgroundLogger: logger)
        let clientTask = Task {
            await client.run()
        }

        do {
            _ = try await client.query("SELECT 1", logger: logger)
        } catch {
            clientTask.cancel()
            throw DatabaseError.connectionFailed("Failed to connect: \(error.localizedDescription)")
        }

        return PostgresSession(client: client, clientTask: clientTask, logger: logger)
    }
}

final class PostgresSession: DatabaseSession {
    private let client: PostgresClient
    private let clientTask: Task<Void, Never>
    private let logger: Logger

    init(client: PostgresClient, clientTask: Task<Void, Never>, logger: Logger) {
        self.client = client
        self.clientTask = clientTask
        self.logger = logger
    }

    func close() async {
        clientTask.cancel()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: logger)

        // Basic result handling until richer grid support is reintroduced.
        var rows: [[String?]] = []
        for try await stringValue in result.decode(String.self) {
            rows.append([stringValue])
        }

        let columns: [ColumnInfo]
        if rows.isEmpty {
            columns = [ColumnInfo(name: "result", dataType: "text")]
        } else {
            columns = [ColumnInfo(name: "value", dataType: "text")]
        }

        return QueryResultSet(columns: columns, rows: rows)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let pagedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(pagedSQL)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: logger)

        var count = 0
        for try await _ in result {
            count += 1
        }
        return count
    }

    func listDatabases() async throws -> [String] {
        let sql = """
        SELECT datname
        FROM pg_database
        WHERE datallowconn = true
          AND datistemplate = false
        ORDER BY datname;
        """
        let result = try await performQuery(sql)
        var names: [String] = []
        for try await name in result.decode(String.self) {
            names.append(name)
        }
        return names
    }

    func listSchemas() async throws -> [String] {
        let sql = """
        SELECT schema_name
        FROM information_schema.schemata
        WHERE schema_name NOT IN ('pg_catalog', 'pg_toast', 'information_schema')
        ORDER BY schema_name;
        """
        let result = try await performQuery(sql)
        var schemas: [String] = []
        for try await schema in result.decode(String.self) {
            schemas.append(schema)
        }
        return schemas
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        var objects: [SchemaObjectInfo] = []

        // Tables and standard views
        let tableSQL = """
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = $1
          AND table_type IN ('BASE TABLE', 'VIEW')
        ORDER BY table_type, table_name;
        """
        let tableResult = try await performQuery(tableSQL, binds: [PostgresData(string: schemaName)])
        for try await (name, rawType) in tableResult.decode((String, String).self) {
            let type = SchemaObjectInfo.ObjectType(rawValue: rawType) ?? .table
            let columns = try await getTableSchema(name, schemaName: schemaName)
            objects.append(SchemaObjectInfo(name: name, schema: schemaName, type: type, columns: columns))
        }

        // Materialized views
        let materializedViewSQL = """
        SELECT matviewname
        FROM pg_matviews
        WHERE schemaname = $1
        ORDER BY matviewname;
        """
        let matViewResult = try await performQuery(materializedViewSQL, binds: [PostgresData(string: schemaName)])
        for try await name in matViewResult.decode(String.self) {
            let columns = try await getTableSchema(name, schemaName: schemaName)
            objects.append(SchemaObjectInfo(name: name, schema: schemaName, type: .materializedView, columns: columns))
        }

        // Functions
        let functionSQL = """
        SELECT routine_name
        FROM information_schema.routines
        WHERE specific_schema = $1
          AND routine_type = 'FUNCTION'
        ORDER BY routine_name;
        """
        let functionResult = try await performQuery(functionSQL, binds: [PostgresData(string: schemaName)])
        for try await name in functionResult.decode(String.self) {
            objects.append(SchemaObjectInfo(name: name, schema: schemaName, type: .function))
        }

        // Triggers
        let triggerSQL = """
        SELECT trigger_name, action_timing, event_manipulation, event_object_table
        FROM information_schema.triggers
        WHERE trigger_schema = $1
        ORDER BY trigger_name;
        """
        let triggerResult = try await performQuery(triggerSQL, binds: [PostgresData(string: schemaName)])
        for try await (name, timing, action, table) in triggerResult.decode((String, String, String, String).self) {
            let actionDisplay = "\(timing.uppercased()) \(action.uppercased())".trimmingCharacters(in: .whitespaces)
            let tableName = "\(schemaName).\(table)"
            objects.append(
                SchemaObjectInfo(
                    name: name,
                    schema: schemaName,
                    type: .trigger,
                    columns: [],
                    triggerAction: actionDisplay,
                    triggerTable: tableName
                )
            )
        }

        return objects
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"

        let pkSQL = """
        SELECT kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2;
        """
        let pkResult = try await performQuery(pkSQL, binds: [PostgresData(string: schema), PostgresData(string: tableName)])
        var primaryKeys = Set<String>()
        for try await columnName in pkResult.decode(String.self) {
            primaryKeys.insert(columnName)
        }

        let columnsSQL = """
        SELECT column_name, data_type, is_nullable, character_maximum_length
        FROM information_schema.columns
        WHERE table_schema = $1 AND table_name = $2
        ORDER BY ordinal_position;
        """
        let columnResult = try await performQuery(columnsSQL, binds: [PostgresData(string: schema), PostgresData(string: tableName)])

        var columns: [ColumnInfo] = []
        for try await (name, dataType, isNullable, maxLength) in columnResult.decode((String, String, String, Int?).self) {
            columns.append(
                ColumnInfo(
                    name: name,
                    dataType: dataType,
                    isPrimaryKey: primaryKeys.contains(name),
                    isNullable: isNullable.uppercased() == "YES",
                    maxLength: maxLength
                )
            )
        }
        return columns
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
            let sql = """
            SELECT pg_get_viewdef(format('%I.%I', $1, $2)::regclass, true);
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- View definition unavailable"

        case .function:
            let sql = """
            SELECT pg_catalog.pg_get_functiondef(p.oid)
            FROM pg_proc p
            JOIN pg_namespace n ON n.oid = p.pronamespace
            WHERE n.nspname = $1 AND p.proname = $2
            ORDER BY p.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Function definition unavailable"

        case .trigger:
            let sql = """
            SELECT pg_catalog.pg_get_triggerdef(t.oid, true)
            FROM pg_trigger t
            JOIN pg_class c ON c.oid = t.tgrelid
            JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = $1 AND t.tgname = $2
            ORDER BY t.oid
            LIMIT 1;
            """
            if let definition = try await firstString(sql, binds: [PostgresData(string: schemaName), PostgresData(string: objectName)]) {
                return definition
            }
            return "-- Trigger definition unavailable"
        }
    }

    // MARK: - Helpers

    private func performQuery(_ sql: String, binds: [PostgresData] = []) async throws -> PostgresRowSequence {
        let query = makeQuery(sql, binds: binds)
        return try await client.query(query, logger: logger)
    }

    private func makeQuery(_ sql: String, binds: [PostgresData]) -> PostgresQuery {
        guard !binds.isEmpty else {
            return PostgresQuery(unsafeSQL: sql)
        }

        var bindings = PostgresBindings()
        for bind in binds {
            bindings.append(bind)
        }
        return PostgresQuery(unsafeSQL: sql, binds: bindings)
    }

    private func firstString(_ sql: String, binds: [PostgresData]) async throws -> String? {
        let result = try await performQuery(sql, binds: binds)
        for try await value in result.decode(String?.self) {
            if let value {
                return value
            }
        }
        return nil
    }
}
