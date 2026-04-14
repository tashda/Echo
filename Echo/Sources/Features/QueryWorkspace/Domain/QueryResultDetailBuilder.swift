import Foundation

struct QueryResultDetailRecord: Equatable, Identifiable {
    struct Field: Equatable, Identifiable {
        let id: String
        let name: String
        let value: String
        let dataType: String
        let isPrimaryKey: Bool
        let isNullable: Bool
        let comment: String?
    }

    let id: Int
    let rowIndex: Int
    let fields: [Field]
}

struct QueryResultFieldTypeDescriptor: Equatable, Identifiable {
    let id: String
    let name: String
    let dataType: String
    let allowsNull: Bool
    let isPrimaryKey: Bool
    let maxLengthDescription: String
    let comment: String
}

enum QueryResultDetailBuilder {
    static func record(
        columns: [ColumnInfo],
        rows: [[String?]],
        selectedRowIndex: Int?
    ) -> QueryResultDetailRecord? {
        guard !columns.isEmpty, !rows.isEmpty else { return nil }
        let resolvedIndex = resolvedRowIndex(selectedRowIndex, rowCount: rows.count)
        let row = rows[resolvedIndex]
        let fields = columns.enumerated().map { index, column in
            QueryResultDetailRecord.Field(
                id: column.id,
                name: column.name,
                value: row[safe: index] ?? "NULL",
                dataType: column.dataType,
                isPrimaryKey: column.isPrimaryKey,
                isNullable: column.isNullable,
                comment: column.comment
            )
        }
        return QueryResultDetailRecord(id: resolvedIndex, rowIndex: resolvedIndex, fields: fields)
    }

    static func fieldTypes(columns: [ColumnInfo]) -> [QueryResultFieldTypeDescriptor] {
        columns.map { column in
            QueryResultFieldTypeDescriptor(
                id: column.id,
                name: column.name,
                dataType: column.dataType,
                allowsNull: column.isNullable,
                isPrimaryKey: column.isPrimaryKey,
                maxLengthDescription: column.maxLength.map(String.init) ?? "Variable",
                comment: column.comment ?? ""
            )
        }
    }

    static func resolvedRowIndex(_ selectedRowIndex: Int?, rowCount: Int) -> Int {
        guard rowCount > 0 else { return 0 }
        guard let selectedRowIndex else { return 0 }
        return min(max(selectedRowIndex, 0), rowCount - 1)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
