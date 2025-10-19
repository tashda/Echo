import Foundation
import NIOCore

let ResultStreamingFetchSizeDefaultsKey = "dk.tippr.echo.streaming.fetchSize"
let ResultStreamingFetchRampMultiplierDefaultsKey = "dk.tippr.echo.streaming.fetchRampMultiplier"
let ResultStreamingFetchRampMaxDefaultsKey = "dk.tippr.echo.streaming.fetchRampMax"

public struct QueryResultSet: Sendable {
    public var columns: [ColumnInfo]
    public var rows: [[String?]]
    public var totalRowCount: Int?
    public var commandTag: String?

    public nonisolated init(columns: [ColumnInfo], rows: [[String?]] = [], totalRowCount: Int? = nil, commandTag: String? = nil) {
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
    public var foreignKey: ForeignKeyReference?

    public nonisolated init(name: String, dataType: String, isPrimaryKey: Bool = false, isNullable: Bool = true, maxLength: Int? = nil, foreignKey: ForeignKeyReference? = nil) {
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isNullable = isNullable
        self.maxLength = maxLength
        self.foreignKey = foreignKey
    }

    public struct ForeignKeyReference: Sendable, Codable, Hashable {
        public let constraintName: String
        public let referencedSchema: String
        public let referencedTable: String
        public let referencedColumn: String

        public init(constraintName: String, referencedSchema: String, referencedTable: String, referencedColumn: String) {
            self.constraintName = constraintName
            self.referencedSchema = referencedSchema
            self.referencedTable = referencedTable
            self.referencedColumn = referencedColumn
        }
    }
}

enum ResultGridValueKind: Sendable, Equatable {
    case text
    case numeric
    case boolean
    case temporal
    case binary
    case identifier
    case json
    case null
}

enum ResultGridValueClassifier {
    private static let numericTypeTokens: Set<String> = [
        "int", "integer", "smallint", "bigint", "tinyint", "mediumint",
        "int2", "int4", "int8", "serial", "bigserial", "smallserial",
        "decimal", "numeric", "real", "float", "float4", "float8",
        "double", "doubleprecision", "money", "number"
    ]

    private static let booleanTypeTokens: Set<String> = [
        "bool", "boolean"
    ]

    private static let temporalTypeTokens: Set<String> = [
        "date", "time", "timestamp", "datetime", "timestamptz", "timetz", "interval", "year"
    ]

    private static let binaryTypeTokens: Set<String> = [
        "bytea", "blob", "binary", "varbinary", "image", "bfile", "raw"
    ]

    private static let jsonTypeTokens: Set<String> = [
        "json", "jsonb"
    ]

    private static let identifierTypeTokens: Set<String> = [
        "uuid", "uniqueidentifier"
    ]

    private static let bitBooleanExclusionTokens: Set<String> = [
        "varying", "var", "binary"
    ]

    static func kind(for column: ColumnInfo?, value: String?) -> ResultGridValueKind {
        guard value != nil else { return .null }
        guard let column else { return .text }
        let tokens = normalizedTypeTokens(for: column.dataType)
        return kind(for: tokens)
    }

    static func kind(forDataType dataType: String?, value: String?) -> ResultGridValueKind {
        guard value != nil else { return .null }
        guard let dataType else { return .text }
        let tokens = normalizedTypeTokens(for: dataType)
        return kind(for: tokens)
    }

    private static func kind(for tokens: [String]) -> ResultGridValueKind {
        guard !tokens.isEmpty else { return .text }
        let tokenSet = Set(tokens)

        if !tokenSet.intersection(booleanTypeTokens).isEmpty {
            return .boolean
        }

        if tokenSet.contains("bit") && tokenSet.intersection(bitBooleanExclusionTokens).isEmpty {
            return .boolean
        }

        if !tokenSet.intersection(numericTypeTokens).isEmpty {
            return .numeric
        }

        if !tokenSet.intersection(temporalTypeTokens).isEmpty {
            return .temporal
        }

        if !tokenSet.intersection(jsonTypeTokens).isEmpty {
            return .json
        }

        if !tokenSet.intersection(identifierTypeTokens).isEmpty {
            return .identifier
        }

        if !tokenSet.intersection(binaryTypeTokens).isEmpty
            || (tokenSet.contains("bit") && !tokenSet.intersection(bitBooleanExclusionTokens).isEmpty) {
            return .binary
        }

        return .text
    }

    private static func normalizedTypeTokens(for rawType: String) -> [String] {
        let lowered = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        return lowered.components(separatedBy: separators).filter { !$0.isEmpty }
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

public struct TableStructureDetails: Sendable, Codable, Hashable {
    public struct Column: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var dataType: String
        public var isNullable: Bool
        public var defaultValue: String?
        public var generatedExpression: String?

        public init(name: String, dataType: String, isNullable: Bool, defaultValue: String?, generatedExpression: String?) {
            self.name = name
            self.dataType = dataType
            self.isNullable = isNullable
            self.defaultValue = defaultValue
            self.generatedExpression = generatedExpression
        }
    }

    public struct PrimaryKey: Sendable, Codable, Hashable {
        public var name: String
        public var columns: [String]

        public init(name: String, columns: [String]) {
            self.name = name
            self.columns = columns
        }
    }

    public struct Index: Identifiable, Sendable, Codable, Hashable {
        public struct Column: Identifiable, Sendable, Codable, Hashable {
            public enum SortOrder: String, Sendable, Codable, Hashable {
                case ascending
                case descending
            }

            public var id: Int { position }
            public var name: String
            public var position: Int
            public var sortOrder: SortOrder

            public init(name: String, position: Int, sortOrder: SortOrder) {
                self.name = name
                self.position = position
                self.sortOrder = sortOrder
            }
        }

        public var id: String { name }
        public var name: String
        public var columns: [Column]
        public var isUnique: Bool
        public var filterCondition: String?

        public init(name: String, columns: [Column], isUnique: Bool, filterCondition: String?) {
            self.name = name
            self.columns = columns
            self.isUnique = isUnique
            self.filterCondition = filterCondition
        }
    }

    public struct UniqueConstraint: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var columns: [String]

        public init(name: String, columns: [String]) {
            self.name = name
            self.columns = columns
        }
    }

    public struct ForeignKey: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var columns: [String]
        public var referencedSchema: String
        public var referencedTable: String
        public var referencedColumns: [String]
        public var onUpdate: String?
        public var onDelete: String?

        public init(
            name: String,
            columns: [String],
            referencedSchema: String,
            referencedTable: String,
            referencedColumns: [String],
            onUpdate: String?,
            onDelete: String?
        ) {
            self.name = name
            self.columns = columns
            self.referencedSchema = referencedSchema
            self.referencedTable = referencedTable
            self.referencedColumns = referencedColumns
            self.onUpdate = onUpdate
            self.onDelete = onDelete
        }
    }

    public struct Dependency: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var baseColumns: [String]
        public var referencedTable: String
        public var referencedColumns: [String]
        public var onUpdate: String?
        public var onDelete: String?

        public init(
            name: String,
            baseColumns: [String],
            referencedTable: String,
            referencedColumns: [String],
            onUpdate: String?,
            onDelete: String?
        ) {
            self.name = name
            self.baseColumns = baseColumns
            self.referencedTable = referencedTable
            self.referencedColumns = referencedColumns
            self.onUpdate = onUpdate
            self.onDelete = onDelete
        }
    }

    public var columns: [Column]
    public var primaryKey: PrimaryKey?
    public var indexes: [Index]
    public var uniqueConstraints: [UniqueConstraint]
    public var foreignKeys: [ForeignKey]
    public var dependencies: [Dependency]

    public init(
        columns: [Column] = [],
        primaryKey: PrimaryKey? = nil,
        indexes: [Index] = [],
        uniqueConstraints: [UniqueConstraint] = [],
        foreignKeys: [ForeignKey] = [],
        dependencies: [Dependency] = []
    ) {
        self.columns = columns
        self.primaryKey = primaryKey
        self.indexes = indexes
        self.uniqueConstraints = uniqueConstraints
        self.foreignKeys = foreignKeys
        self.dependencies = dependencies
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

public struct SortCriteria: Sendable, Equatable {
    public let column: String
    public let ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

public struct QueryStreamMetrics: Sendable, Codable {
    public let batchRowCount: Int
    public let loopElapsed: TimeInterval
    public let decodeDuration: TimeInterval
    public let totalElapsed: TimeInterval
    public let cumulativeRowCount: Int
    public let fetchRequestRowCount: Int?
    public let fetchRowCount: Int?
    public let fetchDuration: TimeInterval?
    public let fetchWait: TimeInterval?

    public nonisolated init(
        batchRowCount: Int,
        loopElapsed: TimeInterval,
        decodeDuration: TimeInterval,
        totalElapsed: TimeInterval,
        cumulativeRowCount: Int,
        fetchRequestRowCount: Int? = nil,
        fetchRowCount: Int? = nil,
        fetchDuration: TimeInterval? = nil,
        fetchWait: TimeInterval? = nil
    ) {
        self.batchRowCount = batchRowCount
        self.loopElapsed = loopElapsed
        self.decodeDuration = decodeDuration
        self.totalElapsed = totalElapsed
        self.cumulativeRowCount = cumulativeRowCount
        self.fetchRequestRowCount = fetchRequestRowCount
        self.fetchRowCount = fetchRowCount
        self.fetchDuration = fetchDuration
        self.fetchWait = fetchWait
    }

    public nonisolated var networkWaitEstimate: TimeInterval {
        if let fetchWait {
            return fetchWait
        }
        return max(loopElapsed - decodeDuration, 0)
    }
}

public struct ResultBinaryRow: Sendable {
    public enum Storage: Sendable {
        case data(Data)
        case raw(Raw)
    }

    public struct Raw: @unchecked Sendable {
        public let buffers: [ByteBuffer?]
        public let lengths: [Int]
        public let totalLength: Int

        public init(buffers: [ByteBuffer?], lengths: [Int], totalLength: Int) {
            self.buffers = buffers
            self.lengths = lengths
            self.totalLength = totalLength
        }
    }

    public let storage: Storage

    public nonisolated init(data: Data) {
        self.storage = .data(data)
    }

    internal nonisolated init(raw: Raw) {
        self.storage = .raw(raw)
    }

    public nonisolated var data: Data {
        switch storage {
        case .data(let data):
            return data
        case .raw(let raw):
            var result = Data()
            result.reserveCapacity(raw.totalLength)

            var flagNull: UInt8 = 0x00
            var flagValue: UInt8 = 0x01

            for (index, length) in raw.lengths.enumerated() {
                if length < 0 {
                    result.append(&flagNull, count: 1)
                    continue
                }

                result.append(&flagValue, count: 1)
                var le = UInt32(length).littleEndian
                withUnsafeBytes(of: &le) { pointer in
                    result.append(pointer.bindMemory(to: UInt8.self))
                }
                if length > 0, let buffer = raw.buffers[index] {
                    result.append(contentsOf: buffer.readableBytesView)
                }
            }
            return result
        }
    }
}

public struct QueryStreamUpdate: Sendable {
    public let columns: [ColumnInfo]
    public let appendedRows: [[String?]]
    public let encodedRows: [ResultBinaryRow]
    public let totalRowCount: Int
    public let metrics: QueryStreamMetrics?
    public let rowRange: Range<Int>?

    public nonisolated init(
        columns: [ColumnInfo],
        appendedRows: [[String?]],
        encodedRows: [ResultBinaryRow] = [],
        totalRowCount: Int,
        metrics: QueryStreamMetrics? = nil,
        rowRange: Range<Int>? = nil
    ) {
        self.columns = columns
        self.appendedRows = appendedRows
        self.encodedRows = encodedRows
        self.totalRowCount = totalRowCount
        self.metrics = metrics
        self.rowRange = rowRange
    }
}

public typealias QueryProgressHandler = @Sendable (QueryStreamUpdate) -> Void



public protocol DatabaseSession: Sendable {
    func close() async
    func simpleQuery(_ sql: String) async throws -> QueryResultSet
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet
    func listTablesAndViews(schema: String?) async throws -> [SchemaObjectInfo]
    func listDatabases() async throws -> [String]
    func listSchemas() async throws -> [String]
    func queryWithPaging(_ sql: String, limit: Int, offset: Int) async throws -> QueryResultSet
    func getTableSchema(_ tableName: String, schemaName: String?) async throws -> [ColumnInfo]
    func getObjectDefinition(objectName: String, schemaName: String, objectType: SchemaObjectInfo.ObjectType) async throws -> String
    func executeUpdate(_ sql: String) async throws -> Int
    func getTableStructureDetails(schema: String, table: String) async throws -> TableStructureDetails
}

public protocol DatabaseFactory {
    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        authentication: DatabaseAuthenticationConfiguration
    ) async throws -> DatabaseSession
}

public protocol DatabaseMetadataSession: DatabaseSession {
    func loadSchemaInfo(
        _ schemaName: String,
        progress: (@Sendable (SchemaObjectInfo.ObjectType, Int, Int) async -> Void)?
    ) async throws -> SchemaInfo
}

public extension DatabaseSession {
    func simpleQuery(_ sql: String, progressHandler: QueryProgressHandler?) async throws -> QueryResultSet {
        try await simpleQuery(sql)
    }
}
