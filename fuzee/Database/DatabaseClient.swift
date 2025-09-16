import Foundation

public struct QueryResultSet: Sendable {
    public let columns: [ColumnInfo]
    public let rows: [[String?]]
    public let totalRowCount: Int?

    public init(columns: [ColumnInfo], rows: [[String?]], totalRowCount: Int? = nil) {
        self.columns = columns
        self.rows = rows
        self.totalRowCount = totalRowCount
    }

    // Legacy initializer for compatibility

    public init(columns: [String], rows: [[String?]]) {
        self.columns = columns.map {
            ColumnInfo(name: $0, dataType: "text")
        }
        self.rows = rows
        self.totalRowCount = nil
    }
}

public struct ColumnInfo: Sendable {
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
    func listTablesAndViews() async throws -> [String]
    // Enhanced query capabilities
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo]
    func executeUpdate(_ sql: String) async throws -> Int
}

public protocol DatabaseFactory {
    func connect(host: String, port: Int, username: String, password: String?, database: String, tls: Bool) async throws -> DatabaseSession
}

