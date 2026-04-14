import Foundation

struct SQLiteRawColumn: Sendable {
    let name: String
    let dataType: String
    let isPrimaryKey: Bool
    let isNullable: Bool
    let maxLength: Int?
}

struct SQLiteRawIndexColumn: Sendable {
    let name: String
    let position: Int
    let isAscending: Bool
}

struct SQLiteRawIndex: Sendable {
    let name: String
    let isUnique: Bool
    let columns: [SQLiteRawIndexColumn]
    let filterCondition: String?
}

struct SQLiteRawForeignKey: Sendable {
    let id: Int
    let referencedTable: String
    let columns: [String]
    let referencedColumns: [String]
    let onUpdate: String?
    let onDelete: String?
}

extension SchemaObjectInfo.ObjectType {
    init?(sqliteType: String) {
        switch sqliteType.lowercased() {
        case "table": self = .table
        case "view": self = .view
        case "trigger": self = .trigger
        default: return nil
        }
    }
}
