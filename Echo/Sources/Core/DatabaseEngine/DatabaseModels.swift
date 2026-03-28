import Foundation

public struct SchemaObjectInfo: Sendable, Identifiable, Codable, Hashable {
    public enum ObjectType: String, Sendable, CaseIterable, Codable {
        case table = "BASE TABLE"
        case view = "VIEW"
        case materializedView = "MATERIALIZED VIEW"
        case function = "FUNCTION"
        case trigger = "TRIGGER"
        case procedure = "PROCEDURE"
        case `extension` = "EXTENSION"
        case sequence = "SEQUENCE"
        case type = "TYPE"
        case synonym = "SYNONYM"

        public nonisolated var pluralDisplayName: String {
            switch self {
            case .table: return "Tables"
            case .view: return "Views"
            case .materializedView: return "Materialized Views"
            case .function: return "Functions"
            case .procedure: return "Procedures"
            case .trigger: return "Triggers"
            case .extension: return "Extensions"
            case .sequence: return "Sequences"
            case .type: return "Types"
            case .synonym: return "Synonyms"
            }
        }

        public nonisolated var systemImage: String {
            switch self {
            case .table: return "tablecells"
            case .view: return "eye"
            case .materializedView: return "eye.fill"
            case .function: return "function"
            case .procedure: return "terminal"
            case .trigger: return "bolt.fill"
            case .extension: return "puzzlepiece.fill"
            case .sequence: return "number"
            case .type: return "t.square"
            case .synonym: return "arrow.triangle.branch"
            }
        }
    }

    public nonisolated var id: String {
        if type == .trigger {
            return "\(schema).\(name).\(triggerTable ?? "").\(triggerAction ?? "")"
        }
        return fullName
    }
    public let name: String
    public let schema: String
    public let type: ObjectType
    public var columns: [ColumnInfo]
    public var parameters: [ProcedureParameterInfo]
    public let triggerAction: String?
    public let triggerTable: String?
    public let comment: String?
    /// True when this table has system-versioning enabled (MSSQL temporal table).
    public var isSystemVersioned: Bool?
    /// True when this table is a history table for a system-versioned table.
    public var isHistoryTable: Bool?
    /// True when this table is memory-optimized (MSSQL In-Memory OLTP).
    public var isMemoryOptimized: Bool?

    public nonisolated init(
        name: String,
        schema: String,
        type: ObjectType,
        columns: [ColumnInfo] = [],
        parameters: [ProcedureParameterInfo] = [],
        triggerAction: String? = nil,
        triggerTable: String? = nil,
        comment: String? = nil,
        isSystemVersioned: Bool? = nil,
        isHistoryTable: Bool? = nil,
        isMemoryOptimized: Bool? = nil
    ) {
        self.name = name
        self.schema = schema
        self.type = type
        self.columns = columns
        self.parameters = parameters
        self.triggerAction = triggerAction
        self.triggerTable = triggerTable
        self.comment = comment
        self.isSystemVersioned = isSystemVersioned
        self.isHistoryTable = isHistoryTable
        self.isMemoryOptimized = isMemoryOptimized
    }

    public nonisolated var fullName: String {
        "\(schema).\(name)"
    }

    private enum CodingKeys: String, CodingKey {
        case name, schema, type, columns, parameters, triggerAction, triggerTable, comment
        case isSystemVersioned, isHistoryTable, isMemoryOptimized
    }

    public nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.schema = try container.decode(String.self, forKey: .schema)
        self.type = try container.decode(ObjectType.self, forKey: .type)
        self.columns = try container.decodeIfPresent([ColumnInfo].self, forKey: .columns) ?? []
        self.parameters = try container.decodeIfPresent([ProcedureParameterInfo].self, forKey: .parameters) ?? []
        self.triggerAction = try container.decodeIfPresent(String.self, forKey: .triggerAction)
        self.triggerTable = try container.decodeIfPresent(String.self, forKey: .triggerTable)
        self.comment = try container.decodeIfPresent(String.self, forKey: .comment)
        self.isSystemVersioned = try container.decodeIfPresent(Bool.self, forKey: .isSystemVersioned)
        self.isHistoryTable = try container.decodeIfPresent(Bool.self, forKey: .isHistoryTable)
        self.isMemoryOptimized = try container.decodeIfPresent(Bool.self, forKey: .isMemoryOptimized)
    }

    public nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(schema, forKey: .schema)
        try container.encode(type, forKey: .type)
        if !columns.isEmpty { try container.encode(columns, forKey: .columns) }
        if !parameters.isEmpty { try container.encode(parameters, forKey: .parameters) }
        try container.encodeIfPresent(triggerAction, forKey: .triggerAction)
        try container.encodeIfPresent(triggerTable, forKey: .triggerTable)
        try container.encodeIfPresent(comment, forKey: .comment)
        try container.encodeIfPresent(isSystemVersioned, forKey: .isSystemVersioned)
        try container.encodeIfPresent(isHistoryTable, forKey: .isHistoryTable)
        try container.encodeIfPresent(isMemoryOptimized, forKey: .isMemoryOptimized)
    }
}

public struct ProcedureParameterInfo: Sendable, Codable, Hashable {
    public var name: String
    public var dataType: String
    public var isOutput: Bool
    public var hasDefaultValue: Bool
    public var maxLength: Int?
    public var ordinalPosition: Int

    public nonisolated init(name: String, dataType: String, isOutput: Bool, hasDefaultValue: Bool, maxLength: Int?, ordinalPosition: Int) {
        self.name = name
        self.dataType = dataType
        self.isOutput = isOutput
        self.hasDefaultValue = hasDefaultValue
        self.maxLength = maxLength
        self.ordinalPosition = ordinalPosition
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
        public var isIdentity: Bool
        public var identitySeed: Int?
        public var identityIncrement: Int?
        public var identityGeneration: String?
        public var collation: String?

        public init(name: String, dataType: String, isNullable: Bool, defaultValue: String?, generatedExpression: String?, isIdentity: Bool = false, identitySeed: Int? = nil, identityIncrement: Int? = nil, identityGeneration: String? = nil, collation: String? = nil) {
            self.name = name; self.dataType = dataType; self.isNullable = isNullable; self.defaultValue = defaultValue; self.generatedExpression = generatedExpression
            self.isIdentity = isIdentity; self.identitySeed = identitySeed; self.identityIncrement = identityIncrement; self.identityGeneration = identityGeneration; self.collation = collation
        }
    }

    public struct PrimaryKey: Sendable, Codable, Hashable {
        public var name: String
        public var columns: [String]
        public var isDeferrable: Bool
        public var isInitiallyDeferred: Bool
        public init(name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
        }
    }

    public struct Index: Identifiable, Sendable, Codable, Hashable {
        public struct Column: Identifiable, Sendable, Codable, Hashable {
            public enum SortOrder: String, Sendable, Codable, Hashable { case ascending, descending }
            public var id: Int { position }
            public var name: String
            public var position: Int
            public var sortOrder: SortOrder
            public var isIncluded: Bool
            public init(name: String, position: Int, sortOrder: SortOrder, isIncluded: Bool = false) {
                self.name = name; self.position = position; self.sortOrder = sortOrder; self.isIncluded = isIncluded
            }
        }
        public var id: String { name }
        public var name: String
        public var columns: [Column]
        public var isUnique: Bool
        public var filterCondition: String?
        public var indexType: String?
        public init(name: String, columns: [Column], isUnique: Bool, filterCondition: String?, indexType: String? = nil) {
            self.name = name; self.columns = columns; self.isUnique = isUnique; self.filterCondition = filterCondition; self.indexType = indexType
        }
    }

    public struct UniqueConstraint: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var columns: [String]
        public var isDeferrable: Bool
        public var isInitiallyDeferred: Bool
        public init(name: String, columns: [String], isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.name = name; self.columns = columns; self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
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
        public var isDeferrable: Bool
        public var isInitiallyDeferred: Bool
        public init(name: String, columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?, isDeferrable: Bool = false, isInitiallyDeferred: Bool = false) {
            self.name = name; self.columns = columns; self.referencedSchema = referencedSchema; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns; self.onUpdate = onUpdate; self.onDelete = onDelete
            self.isDeferrable = isDeferrable; self.isInitiallyDeferred = isInitiallyDeferred
        }
    }

    public struct CheckConstraint: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var expression: String
        public init(name: String, expression: String) { self.name = name; self.expression = expression }
    }

    public struct Dependency: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var baseColumns: [String]
        public var referencedTable: String
        public var referencedColumns: [String]
        public var onUpdate: String?
        public var onDelete: String?
        public init(name: String, baseColumns: [String], referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?) {
            self.name = name; self.baseColumns = baseColumns; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns; self.onUpdate = onUpdate; self.onDelete = onDelete
        }
    }

    public struct TableProperties: Sendable, Codable, Hashable {
        // Common
        public var fillfactor: Int?
        // Postgres
        public var toastTupleTarget: Int?
        public var autovacuumEnabled: Bool?
        public var parallelWorkers: Int?
        public var tablespace: String?
        // MSSQL — General
        public var dataCompression: String?
        public var filegroup: String?
        public var lockEscalation: String?
        public var createdDate: String?
        public var modifiedDate: String?
        public var isSystemObject: Bool?
        public var usesAnsiNulls: Bool?
        public var isReplicated: Bool?
        // MSSQL — Storage
        public var textFilegroup: String?
        public var filestreamFilegroup: String?
        public var isPartitioned: Bool?
        public var partitionScheme: String?
        public var partitionColumn: String?
        public var partitionCount: Int?
        // MSSQL — Temporal
        public var isSystemVersioned: Bool?
        public var historyTableSchema: String?
        public var historyTableName: String?
        public var periodStartColumn: String?
        public var periodEndColumn: String?
        // MSSQL — In-Memory OLTP
        public var isMemoryOptimized: Bool?
        public var memoryOptimizedDurability: String?
        // MSSQL — Change Tracking
        public var changeTrackingEnabled: Bool?
        public var trackColumnsUpdated: Bool?
        // MySQL — Table Options
        public var storageEngine: String?
        public var characterSet: String?
        public var collation: String?
        public var autoIncrementValue: Int?
        public var rowFormat: String?
        public var tableComment: String?
        public var estimatedRowCount: Int64?
        public var dataLengthBytes: Int64?
        public var indexLengthBytes: Int64?

        public init(
            fillfactor: Int? = nil, toastTupleTarget: Int? = nil, autovacuumEnabled: Bool? = nil,
            parallelWorkers: Int? = nil, tablespace: String? = nil, dataCompression: String? = nil,
            filegroup: String? = nil, lockEscalation: String? = nil,
            createdDate: String? = nil, modifiedDate: String? = nil,
            isSystemObject: Bool? = nil, usesAnsiNulls: Bool? = nil, isReplicated: Bool? = nil,
            textFilegroup: String? = nil, filestreamFilegroup: String? = nil,
            isPartitioned: Bool? = nil, partitionScheme: String? = nil, partitionColumn: String? = nil, partitionCount: Int? = nil,
            isSystemVersioned: Bool? = nil, historyTableSchema: String? = nil, historyTableName: String? = nil,
            periodStartColumn: String? = nil, periodEndColumn: String? = nil,
            isMemoryOptimized: Bool? = nil, memoryOptimizedDurability: String? = nil,
            changeTrackingEnabled: Bool? = nil, trackColumnsUpdated: Bool? = nil,
            storageEngine: String? = nil, characterSet: String? = nil, collation: String? = nil, autoIncrementValue: Int? = nil,
            rowFormat: String? = nil, tableComment: String? = nil, estimatedRowCount: Int64? = nil,
            dataLengthBytes: Int64? = nil, indexLengthBytes: Int64? = nil
        ) {
            self.fillfactor = fillfactor; self.toastTupleTarget = toastTupleTarget; self.autovacuumEnabled = autovacuumEnabled; self.parallelWorkers = parallelWorkers; self.tablespace = tablespace
            self.dataCompression = dataCompression; self.filegroup = filegroup; self.lockEscalation = lockEscalation
            self.createdDate = createdDate; self.modifiedDate = modifiedDate
            self.isSystemObject = isSystemObject; self.usesAnsiNulls = usesAnsiNulls; self.isReplicated = isReplicated
            self.textFilegroup = textFilegroup; self.filestreamFilegroup = filestreamFilegroup
            self.isPartitioned = isPartitioned; self.partitionScheme = partitionScheme; self.partitionColumn = partitionColumn; self.partitionCount = partitionCount
            self.isSystemVersioned = isSystemVersioned; self.historyTableSchema = historyTableSchema; self.historyTableName = historyTableName
            self.periodStartColumn = periodStartColumn; self.periodEndColumn = periodEndColumn
            self.isMemoryOptimized = isMemoryOptimized; self.memoryOptimizedDurability = memoryOptimizedDurability
            self.changeTrackingEnabled = changeTrackingEnabled; self.trackColumnsUpdated = trackColumnsUpdated
            self.storageEngine = storageEngine; self.characterSet = characterSet; self.collation = collation; self.autoIncrementValue = autoIncrementValue
            self.rowFormat = rowFormat; self.tableComment = tableComment; self.estimatedRowCount = estimatedRowCount
            self.dataLengthBytes = dataLengthBytes; self.indexLengthBytes = indexLengthBytes
        }
    }

    public var columns: [Column]
    public var primaryKey: PrimaryKey?
    public var indexes: [Index]
    public var uniqueConstraints: [UniqueConstraint]
    public var foreignKeys: [ForeignKey]
    public var dependencies: [Dependency]
    public var checkConstraints: [CheckConstraint]
    public var tableProperties: TableProperties?

    public init(columns: [Column] = [], primaryKey: PrimaryKey? = nil, indexes: [Index] = [], uniqueConstraints: [UniqueConstraint] = [], foreignKeys: [ForeignKey] = [], dependencies: [Dependency] = [], checkConstraints: [CheckConstraint] = [], tableProperties: TableProperties? = nil) {
        self.columns = columns; self.primaryKey = primaryKey; self.indexes = indexes; self.uniqueConstraints = uniqueConstraints; self.foreignKeys = foreignKeys; self.dependencies = dependencies; self.checkConstraints = checkConstraints; self.tableProperties = tableProperties
    }
}

/// A name-value pair of metadata attached to a SQL Server database object.
public struct ExtendedPropertyInfo: Sendable, Identifiable, Hashable {
    public var id: String { name }
    public var name: String
    public var value: String

    public nonisolated init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

// MARK: - Maintenance Models

public struct DatabaseMaintenanceResult: Sendable, Equatable {
    public let operation: String
    public let messages: [String]
    public let succeeded: Bool

    public init(operation: String, messages: [String], succeeded: Bool) {
        self.operation = operation; self.messages = messages; self.succeeded = succeeded
    }
}

public struct SQLServerTableStat: Sendable, Identifiable {
    public var id: String { "\(schemaName).\(tableName)" }
    public let schemaName: String
    public let tableName: String
    public let tableType: String // "Heap" or "Clustered"
    public let rowCount: Int64
    public let dataSpaceKB: Int64
    public let indexSpaceKB: Int64
    public let unusedSpaceKB: Int64
    public let totalSpaceKB: Int64
    public let lastStatsUpdate: Date?
    public let forwardedRecords: Int64?

    public var totalSpaceBytes: Int64 { totalSpaceKB * 1024 }
    public var dataSpaceBytes: Int64 { dataSpaceKB * 1024 }
    public var indexSpaceBytes: Int64 { indexSpaceKB * 1024 }
    public var unusedSpaceBytes: Int64 { unusedSpaceKB * 1024 }

    public var isHeap: Bool { tableType == "Heap" }

    /// Seconds since epoch for sorting — 0 if never updated
    public var lastStatsUpdateSort: TimeInterval {
        lastStatsUpdate?.timeIntervalSince1970 ?? 0
    }

    public var unusedRatio: Double {
        totalSpaceKB > 0 ? Double(unusedSpaceKB) / Double(totalSpaceKB) * 100 : 0
    }

    public var status: String {
        if let fwd = forwardedRecords, fwd > 1000 {
            return "Forwarded"
        }
        // Only flag wasted space when both the ratio is high AND there's meaningful absolute waste
        // Small tables naturally have high unused ratios due to extent-based allocation (64KB minimum)
        if unusedRatio > 40 && unusedSpaceKB > 1024 {
            return "Wasted Space"
        }
        return "Healthy"
    }

    public init(
        schemaName: String,
        tableName: String,
        tableType: String,
        rowCount: Int64,
        dataSpaceKB: Int64,
        indexSpaceKB: Int64,
        unusedSpaceKB: Int64,
        totalSpaceKB: Int64,
        lastStatsUpdate: Date?,
        forwardedRecords: Int64?
    ) {
        self.schemaName = schemaName; self.tableName = tableName; self.tableType = tableType
        self.rowCount = rowCount; self.dataSpaceKB = dataSpaceKB; self.indexSpaceKB = indexSpaceKB
        self.unusedSpaceKB = unusedSpaceKB; self.totalSpaceKB = totalSpaceKB
        self.lastStatsUpdate = lastStatsUpdate; self.forwardedRecords = forwardedRecords
    }
}

public struct SQLServerIndexFragmentation: Sendable, Identifiable {
    public var id: String { "\(schemaName).\(tableName).\(indexName)" }
    public let schemaName: String
    public let tableName: String
    public let indexName: String
    public let fragmentationPercent: Double
    public let pageCount: Int64
    public let indexType: String
    public let indexId: Int
    public let isUnique: Bool
    public let isPrimaryKey: Bool
    public let totalScans: Int64
    public let totalUpdates: Int64
    public let sizeKB: Double
    public let tableSizeKB: Double
    public let lastStatsUpdate: Date?

    public var ratio: Double {
        tableSizeKB > 0 ? (sizeKB / tableSizeKB) * 100 : 0
    }
    
    public var status: String {
        if totalScans == 0 && sizeKB > 1024 {
            return "Unused"
        }
        // SQL Server docs: fragmentation values are unreliable for indexes < 1000 pages
        if fragmentationPercent > 30 && pageCount >= 1000 {
            return "Fragmented"
        }
        return "Healthy"
    }

    public init(
        schemaName: String,
        tableName: String,
        indexName: String,
        fragmentationPercent: Double,
        pageCount: Int64,
        indexType: String,
        indexId: Int,
        isUnique: Bool,
        isPrimaryKey: Bool,
        totalScans: Int64,
        totalUpdates: Int64,
        sizeKB: Double,
        tableSizeKB: Double,
        lastStatsUpdate: Date? = nil
    ) {
        self.schemaName = schemaName; self.tableName = tableName; self.indexName = indexName; self.fragmentationPercent = fragmentationPercent; self.pageCount = pageCount; self.indexType = indexType; self.indexId = indexId
        self.isUnique = isUnique; self.isPrimaryKey = isPrimaryKey; self.totalScans = totalScans; self.totalUpdates = totalUpdates; self.sizeKB = sizeKB; self.tableSizeKB = tableSizeKB
        self.lastStatsUpdate = lastStatsUpdate
    }
}

public struct SQLServerBackupHistoryEntry: Sendable, Identifiable {
    public let id: Int
    public let name: String?
    public let description: String?
    public let startDate: Date?
    public let finishDate: Date?
    public let type: String
    public let size: Int64
    public let compressedSize: Int64?
    public let physicalPath: String
    public let serverName: String
    public let recoveryModel: String

    public init(id: Int, name: String?, description: String?, startDate: Date?, finishDate: Date?, type: String, size: Int64, compressedSize: Int64?, physicalPath: String, serverName: String, recoveryModel: String) {
        self.id = id; self.name = name; self.description = description; self.startDate = startDate; self.finishDate = finishDate; self.type = type; self.size = size; self.compressedSize = compressedSize; self.physicalPath = physicalPath; self.serverName = serverName; self.recoveryModel = recoveryModel
    }

    public var typeDescription: String {
        switch type {
        case "D": return "Full"
        case "I": return "Differential"
        case "L": return "Log"
        case "F": return "File or Filegroup"
        case "G": return "Differential File"
        case "P": return "Partial"
        case "Q": return "Differential Partial"
        default: return "Unknown (\(type))"
        }
    }
}

public struct SQLServerDatabaseHealth: Sendable, Codable, Equatable {
    public let name: String
    public let owner: String
    public let createDate: Date
    public let sizeMB: Double
    public let recoveryModel: String
    public let status: String
    public let compatibilityLevel: Int
    public let collationName: String?

    public init(name: String, owner: String, createDate: Date, sizeMB: Double, recoveryModel: String, status: String, compatibilityLevel: Int, collationName: String?) {
        self.name = name; self.owner = owner; self.createDate = createDate; self.sizeMB = sizeMB; self.recoveryModel = recoveryModel; self.status = status; self.compatibilityLevel = compatibilityLevel; self.collationName = collationName
    }
}
