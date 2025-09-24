import Foundation
import Foundation
import PostgresNIO
import Logging

struct PostgresNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "fuzee.postgres.factory")

    func connect(host: String, port: Int, username: String, password: String?, database: String, tls: Bool) async throws -> DatabaseSession {
        logger.info("Connecting to PostgreSQL at \(host):\(port)/\(database)")

        let config = PostgresClient.Configuration(
            host: host,
            port: port,
            username: username,
            password: password,
            database: database,
            tls: tls ? .require(.makeClientConfiguration()): .disable
        )

        let client = PostgresClient(configuration: config, backgroundLogger: logger)
        let clientTask = Task {
            await client.run()
        }

        // Test the connection
        do {
            let _ = try await client.query("SELECT 1", logger: logger)
            logger.info("Connection successful")
        } catch {
            clientTask.cancel()
            throw DatabaseError.connectionFailed("Failed to connect: \(error.localizedDescription)")
        }

        return PostgresSession(client: client, clientTask: clientTask)
    }
}

final class PostgresSession: DatabaseSession {
    let client: PostgresClient
    let clientTask: Task<Void, Never>

    init(client: PostgresClient, clientTask: Task<Void, Never>) {
        self.client = client
        self.clientTask = clientTask
    }

    func close() async {
        clientTask.cancel()
    }

    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        let query = PostgresQuery(unsafeSQL: sql)
        let rows = try await client.query(query, logger: Logger(label: "fuzee.postgres.query"))

        var columns: [ColumnInfo] = []
        var resultRows: [[String?]] = []

        // For table name queries, we know it's just one column
        if sql.contains("table_name") {
            columns = [ColumnInfo(name: "table_name", dataType: "text")]

            for try await stringValue in rows.decode(String.self) {
                resultRows.append([stringValue])
            }
        } else {
            // For other queries, return empty results for now
            // TODO: Implement proper query result handling
            columns = [ColumnInfo(name: "result", dataType: "text")]
        }

        return QueryResultSet(columns: columns, rows: resultRows)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let paginatedSQL = "\(sql) LIMIT \(limit) OFFSET \(offset)"
        return try await simpleQuery(paginatedSQL)
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        let schema = schemaName ?? "public"

        // 1. Get primary key columns
        let pkQuerySQL = """
        SELECT kcu.column_name
        FROM information_schema.table_constraints AS tc
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        WHERE tc.constraint_type = 'PRIMARY KEY'
          AND tc.table_schema = $1
          AND tc.table_name = $2;
        """
        
        var pkBinds = PostgresBindings()
        pkBinds.append(PostgresData(string: schema))
        pkBinds.append(PostgresData(string: tableName))
        let pkQuery = PostgresQuery(unsafeSQL: pkQuerySQL, binds: pkBinds)
        
        let pkRows = try await client.query(
            pkQuery,
            logger: Logger(label: "fuzee.postgres.schema.pk")
        )
        var primaryKeys = Set<String>()
        for try await pkRow in pkRows.decode(String.self) {
            primaryKeys.insert(pkRow)
        }

        // 2. Get all columns
        let columnsQuerySQL = """
        SELECT
            column_name,
            data_type,
            is_nullable,
            character_maximum_length
        FROM
            information_schema.columns
        WHERE
            table_schema = $1 AND table_name = $2
        ORDER BY
            ordinal_position;
        """
        
        var columnBinds = PostgresBindings()
        columnBinds.append(PostgresData(string: schema))
        columnBinds.append(PostgresData(string: tableName))
        let columnQuery = PostgresQuery(unsafeSQL: columnsQuerySQL, binds: columnBinds)

        let columnRows = try await client.query(columnQuery, logger: Logger(label: "fuzee.postgres.schema.columns"))

        var columns: [ColumnInfo] = []
        for try await (name, dataType, isNullableStr, maxLength) in columnRows.decode((String, String, String, Int?).self) {
            let column = ColumnInfo(
                name: name,
                dataType: dataType,
                isPrimaryKey: primaryKeys.contains(name),
                isNullable: isNullableStr.uppercased() == "YES",
                maxLength: maxLength
            )
            columns.append(column)
        }

        return columns
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let query = PostgresQuery(unsafeSQL: sql)
        let rows = try await client.query(query, logger: Logger(label: "fuzee.postgres.update"))

        // Count the affected rows by iterating through all rows
        var count = 0
        for try await _ in rows {
            count += 1
        }
        return count
    }

    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo] {
        let schemaName = schema ?? "public"
        let sql = """
            SELECT table_name, table_type
                    FROM information_schema.tables
                    WHERE table_schema = $1
                        AND table_type IN ('BASE TABLE', 'VIEW')
                    ORDER BY table_type, table_name
        """
        
        var binds = PostgresBindings()
        binds.append(PostgresData(string: schemaName))
        let query = PostgresQuery(unsafeSQL: sql, binds: binds)
        
        let rows = try await client.query(query, logger: Logger(label: "fuzee.postgres.query"))

        var results = [SchemaObjectInfo]()
        for try await (tableName, tableType) in rows.decode((String, String).self) {
            guard let type = SchemaObjectInfo.ObjectType(rawValue: tableType) else {
                continue
            }
            results.append(.init(name: tableName, schema: schemaName, type: type))
        }
        return results
    }
}
