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
            login: .init(database: database ?? "master", authentication: sqlServerAuth),
            tlsConfiguration: tls ? .makeClientConfiguration() : nil
        )

        logger.info("Connecting to SQL Server at \(host):\(port)/\(database ?? "master")")

        // SQLServerClient.connect returns an EventLoopFuture, so we need to await it properly
        let client = try await withCheckedThrowingContinuation { continuation in
            SQLServerClient.connect(configuration: configuration).whenComplete { result in
                switch result {
                case .success(let client):
                    continuation.resume(returning: client)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        // Wrap the SQLServerClient in an adapter that conforms to DatabaseSession
        return SQLServerSessionAdapter(client: client)
    }
}

// MARK: - Session Adapter

/// Adapter to make SQLServerClient conform to Echo's DatabaseSession protocol
final class SQLServerSessionAdapter: DatabaseSession {
    private let client: SQLServerClient

    init(client: SQLServerClient) {
        self.client = client
    }

    func close() async {
        // SQLServerClient doesn't have a close method, so we'll rely on connection pool cleanup
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
        // Use SQLServerKit's listTables method and convert to Echo's format
        let tableMetadata: [TableMetadata] = try await withCheckedThrowingContinuation { continuation in
            client.listTables(database: "master").whenComplete { result in
                switch result {
                case .success(let tables):
                    continuation.resume(returning: tables)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        return tableMetadata.map { table in
            SchemaObjectInfo(
                name: table.name,
                schema: table.schema,
                type: table.type.contains("VIEW") ? .view : .table
            )
        }
    }

    func listDatabases() async throws -> [String] {
        let databaseMetadata = try await withCheckedThrowingContinuation { continuation in
            client.listDatabases().whenComplete { result in
                switch result {
                case .success(let databases):
                    continuation.resume(returning: databases)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        return databaseMetadata.map { $0.name }
    }

    func listSchemas() async throws -> [String] {
        // Use a raw SQL query to get schemas since SQLServerKit doesn't have a direct method
        let query = "SELECT DISTINCT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('sys', 'INFORMATION_SCHEMA')"
        let rows: [TDSRow] = try await client.query(query)

        // Extract schema names from the result
        var schemas: [String] = []
        for row in rows {
            if let schema = row.column("schema_name")?.string {
                schemas.append(schema)
            }
        }
        return schemas
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
        let columnMetadata: [ColumnMetadata] = try await withCheckedThrowingContinuation { continuation in
            client.listColumns(
                database: "master",
                schema: schemaName ?? "dbo",
                table: tableName
            ).whenComplete { result in
                switch result {
                case .success(let columns):
                    continuation.resume(returning: columns)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        return columnMetadata.map { column in
            ColumnInfo(
                name: column.name,
                dataType: column.typeName,
                isPrimaryKey: false, // Would need separate query
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
        let columnMetadata: [ColumnMetadata] = try await withCheckedThrowingContinuation { continuation in
            client.listColumns(
                database: "master",
                schema: schema,
                table: table
            ).whenComplete { result in
                switch result {
                case .success(let columns):
                    continuation.resume(returning: columns)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }

        let columns = columnMetadata.map { column in
            TableStructureDetails.Column(
                name: column.name,
                dataType: column.typeName,
                isNullable: column.isNullable,
                defaultValue: column.defaultDefinition,
                generatedExpression: column.computedDefinition
            )
        }

        return TableStructureDetails(
            columns: columns,
            primaryKey: nil, // Would need separate query
            indexes: [], // Would need separate query
            uniqueConstraints: [],
            foreignKeys: [],
            dependencies: []
        )
    }

    // MARK: - Helper Methods

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

        return data.description
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
