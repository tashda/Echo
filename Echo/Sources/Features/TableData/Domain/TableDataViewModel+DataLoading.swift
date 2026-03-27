import Foundation
import OSLog

extension TableDataViewModel {

    func loadInitialData() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        rows.removeAll()
        columns.removeAll()
        primaryKeyColumns.removeAll()
        currentOffset = 0
        totalLoadedRows = 0
        hasMoreRows = true

        let handle = activityEngine?.begin(
            "Loading \(schemaName).\(tableName)",
            connectionSessionID: connectionSessionID
        )

        do {
            try await detectPrimaryKeyColumns()
            try await fetchPage()
            handle?.succeed()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }

        isLoading = false
    }

    func loadNextPage() async {
        guard !isLoadingMore, hasMoreRows else { return }
        isLoadingMore = true

        do {
            try await fetchPage()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Private

    private func detectPrimaryKeyColumns() async throws {
        let details = try await session.getTableStructureDetails(schema: schemaName, table: tableName)
        if let pk = details.primaryKey, !pk.columns.isEmpty {
            primaryKeyColumns = pk.columns
        }
    }

    private func fetchPage() async throws {
        let sql = buildSelectSQL()
        let result = try await session.simpleQuery(sql)

        // Populate columns on first page
        if columns.isEmpty {
            columns = result.columns.map { col in
                TableDataColumn(
                    name: col.name,
                    dataType: col.dataType,
                    isPrimaryKey: primaryKeyColumns.contains(col.name)
                )
            }
        }

        let newRows = result.rows
        rows.append(contentsOf: newRows)
        totalLoadedRows = rows.count
        currentOffset += newRows.count

        if newRows.count < pageSize {
            hasMoreRows = false
        }
    }

    private func buildSelectSQL() -> String {
        let table = qualifiedTableName
        let orderClause = buildOrderByClause()

        switch databaseType {
        case .microsoftSQL:
            return """
            SELECT * FROM \(table)\(orderClause)
            OFFSET \(currentOffset) ROWS
            FETCH NEXT \(pageSize) ROWS ONLY;
            """
        case .postgresql, .mysql, .sqlite:
            return """
            SELECT * FROM \(table)\(orderClause)
            LIMIT \(pageSize)
            OFFSET \(currentOffset);
            """
        }
    }

    private func buildOrderByClause() -> String {
        if !primaryKeyColumns.isEmpty {
            let cols = primaryKeyColumns.map { quoteIdentifier($0) }.joined(separator: ", ")
            return "\nORDER BY \(cols)"
        }
        // Fall back to first column if no PK
        if let first = columns.first {
            return "\nORDER BY \(quoteIdentifier(first.name))"
        }
        // MSSQL requires ORDER BY for OFFSET/FETCH — use a constant
        if databaseType == .microsoftSQL {
            return "\nORDER BY (SELECT NULL)"
        }
        return ""
    }
}
