import Foundation
import SQLServerKit

extension SQLServerSessionAdapter {
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

    func executeUpdate(_ sql: String) async throws -> Int {
        // Use SQLServerKit's execute method
        let result = try await client.execute(sql)
        return Int(result.rowCount ?? 0)
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
}
