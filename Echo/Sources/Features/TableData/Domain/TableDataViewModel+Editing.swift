import Foundation
import OSLog

extension TableDataViewModel {

    func editCell(
        row: Int,
        column: Int,
        newValue: String?,
        valueMode: TableDataCellValueMode? = nil
    ) {
        guard row < rows.count, column < columns.count else { return }
        let oldValue = rows[row][column]

        // Deduplicate: replace existing edit for same cell
        if let existingIndex = pendingEdits.firstIndex(where: { $0.rowIndex == row && $0.columnIndex == column }) {
            var edit = pendingEdits[existingIndex]
            edit.newValue = newValue
            if let valueMode {
                edit.valueMode = valueMode
            }
            pendingEdits[existingIndex] = edit
        } else {
            pendingEdits.append(CellEdit(
                rowIndex: row,
                columnIndex: column,
                oldValue: oldValue,
                newValue: newValue,
                valueMode: valueMode ?? .literal
            ))
        }

        // Apply the edit to the visible rows
        rows[row][column] = newValue
    }

    func valueMode(row: Int, column: Int) -> TableDataCellValueMode {
        pendingEdits.first(where: { $0.rowIndex == row && $0.columnIndex == column })?.valueMode ?? .literal
    }

    func setCellToNull(row: Int, column: Int) {
        editCell(row: row, column: column, newValue: nil, valueMode: .literal)
    }

    func transformCellText(row: Int, column: Int, using transform: TableDataTextTransform) {
        guard row < rows.count, column < columns.count else { return }
        let currentValue = rows[row][column] ?? ""
        editCell(
            row: row,
            column: column,
            newValue: transform.apply(to: currentValue),
            valueMode: valueMode(row: row, column: column)
        )
    }

    func setValueMode(row: Int, column: Int, to valueMode: TableDataCellValueMode) {
        guard row < rows.count, column < columns.count else { return }
        editCell(
            row: row,
            column: column,
            newValue: rows[row][column],
            valueMode: valueMode
        )
    }

    func loadCellValue(row: Int, column: Int, from url: URL) {
        guard row < rows.count, column < columns.count else { return }

        do {
            let value = try String(contentsOf: url, encoding: .utf8)
            editCell(row: row, column: column, newValue: value, valueMode: .literal)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveChanges() async {
        guard hasPendingEdits, canEdit else { return }

        let handle = activityEngine?.begin(
            "Saving \(pendingEdits.count) edit(s) to \(tableName)",
            connectionSessionID: connectionSessionID
        )

        do {
            // Group edits by row for batch UPDATE per row
            let editsByRow = Dictionary(grouping: pendingEdits) { $0.rowIndex }

            for (rowIndex, edits) in editsByRow {
                let sql = generateUpdateSQL(rowIndex: rowIndex, edits: edits)
                _ = try await session.executeUpdate(sql)
            }

            pendingEdits.removeAll()
            handle?.succeed()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
    }

    func deleteRow(at rowIndex: Int) async {
        guard rowIndex < rows.count, canEdit else { return }

        let handle = activityEngine?.begin(
            "Deleting row from \(tableName)",
            connectionSessionID: connectionSessionID
        )

        do {
            let sql = generateDeleteSQL(for: rowIndex)
            _ = try await session.executeUpdate(sql)
            rows.remove(at: rowIndex)
            totalLoadedRows = rows.count

            // Remove any pending edits referencing this row
            pendingEdits.removeAll { $0.rowIndex == rowIndex }
            // Adjust row indices for edits after the deleted row
            pendingEdits = pendingEdits.map { edit in
                guard edit.rowIndex > rowIndex else { return edit }
                let adjusted = CellEdit(
                    rowIndex: edit.rowIndex - 1,
                    columnIndex: edit.columnIndex,
                    oldValue: edit.oldValue,
                    newValue: edit.newValue
                )
                return adjusted
            }

            handle?.succeed()
        } catch {
            errorMessage = error.localizedDescription
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - SQL Generation

    private func generateUpdateSQL(rowIndex: Int, edits: [CellEdit]) -> String {
        let table = qualifiedTableName
        let setClauses = edits.map { edit -> String in
            let colName = quoteIdentifier(columns[edit.columnIndex].name)
            if let value = edit.newValue {
                return "\(colName) = \(renderSQLValue(value, mode: edit.valueMode))"
            } else {
                return "\(colName) = NULL"
            }
        }.joined(separator: ", ")

        let whereClause = buildWhereClause(for: rowIndex)
        return "UPDATE \(table) SET \(setClauses) WHERE \(whereClause);"
    }

    private func generateDeleteSQL(for rowIndex: Int) -> String {
        let table = qualifiedTableName
        let whereClause = buildWhereClause(for: rowIndex)
        return "DELETE FROM \(table) WHERE \(whereClause);"
    }

    private func buildWhereClause(for rowIndex: Int) -> String {
        guard rowIndex < rows.count else { return "1=0" }
        let row = rows[rowIndex]

        let conditions = primaryKeyColumns.compactMap { pkCol -> String? in
            guard let colIndex = columns.firstIndex(where: { $0.name == pkCol }) else { return nil }
            let colName = quoteIdentifier(pkCol)
            if let value = row[colIndex] {
                return "\(colName) = \(renderSQLValue(value, mode: .literal))"
            } else {
                return "\(colName) IS NULL"
            }
        }

        return conditions.isEmpty ? "1=0" : conditions.joined(separator: " AND ")
    }

    private func renderSQLValue(_ value: String, mode: TableDataCellValueMode) -> String {
        if mode == .expression {
            return value
        }
        let escaped = value.replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}
