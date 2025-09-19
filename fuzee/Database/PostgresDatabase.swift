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
        let result = try await client.query(query, logger: Logger(label: "fuzee.postgres.query"))
        return QueryResultSet(columns: [], rows: [])
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: Logger(label: "fuzee.postgres.query"))
        return QueryResultSet(columns: [], rows: [])
    }

    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo] {
        return []
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: Logger(label: "fuzee.postgres.update"))
        return 0
    }

    func listTablesAndViews() async throws -> [String] {
        let sql = """
            SELECT table_name 
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                        AND table_type IN ('BASE TABLE', 'VIEW')
                    ORDER BY table_name
        """
        let query = PostgresQuery(unsafeSQL: sql)
        let result = try await client.query(query, logger: Logger(label: "fuzee.postgres.schema"))

        var tableNames: [String] = []
        // TODO: Process the results to extract table names
        // For now return empty to avoid syntax issues
        return tableNames
    }
}