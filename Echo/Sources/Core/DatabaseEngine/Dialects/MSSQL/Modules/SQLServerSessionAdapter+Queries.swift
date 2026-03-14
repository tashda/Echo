import Foundation
import SQLServerKit

extension SQLServerSessionAdapter {
    func simpleQuery(_ sql: String) async throws -> QueryResultSet {
        // Use SQLServerKit's query functionality
        let rows: [SQLServerRow] = try await client.query(sql)

        // Convert SQLServerKit result to Echo's QueryResultSet
        return try await convertSQLServerRowsToEcho(rows)
    }

    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        return try await simpleQuery(sql)
    }

    func simpleQuery(_ sql: String, executionMode: ResultStreamingExecutionMode?, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        return try await simpleQuery(sql)
    }

    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet {
        let rows = try await client.queryPaged(sql, limit: limit, offset: offset)
        return try await convertSQLServerRowsToEcho(rows)
    }

    func executeUpdate(_ sql: String) async throws -> Int {
        // Use SQLServerKit's execute method
        let result = try await client.execute(sql)
        return Int(result.rowCount ?? 0)
    }

    func renameTable(schema: String?, oldName: String, newName: String) async throws {
        try await client.admin.renameTable(
            name: oldName,
            newName: newName,
            schema: schema ?? "dbo",
            database: database
        )
    }

    func dropTable(schema: String?, name: String, ifExists: Bool) async throws {
        try await client.admin.dropTable(
            name: name,
            schema: schema ?? "dbo",
            database: database
        )
    }

    func truncateTable(schema: String?, name: String) async throws {
        try await client.admin.truncateTable(
            name: name,
            schema: schema ?? "dbo",
            database: database
        )
    }

    private func convertSQLServerRowsToEcho(_ rows: [SQLServerRow]) async throws -> QueryResultSet {
        var echoColumns: [ColumnInfo] = []
        var echoRows: [[String?]] = []

        if let firstRow = rows.first {
            echoColumns = firstRow.columnMetadata.map { column in
                ColumnInfo(
                    name: column.colName,
                    dataType: column.typeName,
                    isPrimaryKey: false,
                    isNullable: true,
                    maxLength: column.normalizedLength
                )
            }

            echoRows = rows.map { row in
                row.values.map { $0.isNull ? nil : $0.description }
            }
        }

        return QueryResultSet(
            columns: echoColumns,
            rows: echoRows,
            totalRowCount: echoRows.count,
            commandTag: nil
        )
    }
}
