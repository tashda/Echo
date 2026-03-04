import SwiftUI

struct IndexEditorPresentation: Identifiable {
    let id = UUID()
    let indexID: UUID
}

struct ColumnEditorPresentation: Identifiable {
    let id = UUID()
    let columnID: UUID
    let isNew: Bool
}

struct PrimaryKeyEditorPresentation: Identifiable {
    let id = UUID()
    let isNew: Bool
}

struct UniqueConstraintEditorPresentation: Identifiable {
    let id = UUID()
    let constraintID: UUID
    let isNew: Bool
}

struct ForeignKeyEditorPresentation: Identifiable {
    let id = UUID()
    let foreignKeyID: UUID
    let isNew: Bool
}

struct BulkColumnEditorPresentation: Identifiable {
    enum Mode {
        case dataType
        case defaultValue
        case generatedExpression
    }
    let id = UUID()
    let mode: Mode
    let columnIDs: [UUID]
}

let postgresDataTypeOptions: [String] = [
    "bigint", "bigserial", "bit", "bit varying", "boolean", "box", "bytea",
    "character", "character varying", "cidr", "circle", "date", "double precision",
    "inet", "integer", "interval", "json", "jsonb", "line", "lseg", "macaddr",
    "macaddr8", "money", "numeric", "path", "pg_lsn", "point", "polygon", "real",
    "smallint", "smallserial", "serial", "text", "time without time zone",
    "time with time zone", "timestamp without time zone", "timestamp with time zone",
    "tsquery", "tsvector", "txid_snapshot", "uuid", "xml"
].sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
