import Foundation

public struct QueryResultSet: Sendable {
    public var columns: [ColumnInfo]
    public var rows: [[String?]]
    public var totalRowCount: Int?
    public var commandTag: String?

    public init(columns: [ColumnInfo], rows: [[String?]] = [], totalRowCount: Int? = nil, commandTag: String? = nil) {
        self.columns = columns
        self.rows = rows
        self.totalRowCount = totalRowCount ?? rows.count
        self.commandTag = commandTag
    }

    // Legacy initializer for compatibility
    public init(columns: [String], rows: [[String?]]) {
        self.columns = columns.map {
            ColumnInfo(name: $0, dataType: "text")
        }
        self.rows = rows
        self.totalRowCount = rows.count
        self.commandTag = nil
    }
}

public struct ColumnInfo: Sendable, Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let dataType: String
    public let isPrimaryKey: Bool
    public let isNullable: Bool
    public let maxLength: Int?

    public init(name: String, dataType: String, isPrimaryKey: Bool = false, isNullable: Bool = true, maxLength: Int? = nil) {
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isNullable = isNullable
        self.maxLength = maxLength
    }
}

public struct SchemaObjectInfo: Sendable, Identifiable, Codable, Hashable {
    public enum ObjectType: String, Sendable, CaseIterable, Codable {
        case table = "BASE TABLE"
        case view = "VIEW"
        case materializedView = "MATERIALIZED VIEW"
        case function = "FUNCTION"
        case trigger = "TRIGGER"

        public var pluralDisplayName: String {
            switch self {
            case .table: return "Tables"
            case .view: return "Views"
            case .materializedView: return "Materialized Views"
            case .function: return "Functions"
            case .trigger: return "Triggers"
            }
        }

        public var systemImage: String {
            switch self {
            case .table: return "table"
            case .view: return "eye"
            case .materializedView: return "eye.fill"
            case .function: return "function"
            case .trigger: return "bolt"
            }
        }
    }

    public var id: String {
        if type == .trigger {
            return "\(schema).\(name).\(triggerTable ?? "").\(triggerAction ?? "")"
        }
        return fullName
    }
    public let name: String
    public let schema: String
    public let type: ObjectType
    public var columns: [ColumnInfo]
    public let triggerAction: String?
    public let triggerTable: String?

    public init(name: String, schema: String, type: ObjectType, columns: [ColumnInfo] = [], triggerAction: String? = nil, triggerTable: String? = nil) {
        self.name = name
        self.schema = schema
        self.type = type
        self.columns = columns
        self.triggerAction = triggerAction
        self.triggerTable = triggerTable
    }

    public var fullName: String {
        "\(schema).\(name)"
    }
}

public struct FilterCriteria: Sendable {
    public let column: String
    public let `operator`: FilterOperator
    public let value: String

    public init(column: String, `operator`: FilterOperator, value: String) {
        self.column = column
        self.operator = `operator`
        self.value = value
    }
}

public enum FilterOperator: String, CaseIterable, Sendable {
    case equals = "="
    case notEquals = "!="
    case contains = "LIKE"
    case startsWith = "STARTS_WITH"
    case endsWith = "ENDS_WITH"
    case greaterThan = ">"
    case lessThan = "<"
    case isNull = "IS NULL"
    case isNotNull = "IS NOT NULL"
}

public struct SortCriteria: Sendable {
    public let column: String
    public let ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

public protocol DatabaseSession: Sendable {
    func close() async
    func simpleQuery(_ sql: String) async throws -> QueryResultSet
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo]
    func listDatabases() async throws -> [String]
    func listSchemas() async throws -> [String]
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo]
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String
    func executeUpdate(_ sql: String) async throws -> Int
}

public protocol DatabaseFactory {
    func connect(host: String, port: Int, username: String, password: String?, database: String?, tls: Bool) async throws -> DatabaseSession
}
