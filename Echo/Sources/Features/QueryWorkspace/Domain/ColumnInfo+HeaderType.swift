import Foundation

extension ColumnInfo {
    /// The type under a column's name in the results header: an encrypted column's own wording,
    /// or, on PostgreSQL, the data type without the "(OID)" Echo adds for decoding (`DATE(1082)`
    /// reads `DATE`). Other engines' types stay as they are: SQLite's `VARCHAR(255)` is a length.
    nonisolated func headerTypeName(on databaseType: DatabaseType?) -> String {
        if let encrypted = encryption?.typeName { return encrypted }
        guard databaseType == .postgresql, PostgresSpoolColumns.oid(for: dataType) != nil,
              let open = dataType.lastIndex(of: "(") else { return dataType }
        return String(dataType[..<open])
    }
}
