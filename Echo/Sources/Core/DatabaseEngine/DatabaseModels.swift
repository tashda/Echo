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

        public nonisolated var pluralDisplayName: String {
            switch self {
            case .table: return "Tables"
            case .view: return "Views"
            case .materializedView: return "Materialized Views"
            case .function: return "Functions"
            case .procedure: return "Procedures"
            case .trigger: return "Triggers"
            case .extension: return "Extensions"
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

    public nonisolated init(
        name: String,
        schema: String,
        type: ObjectType,
        columns: [ColumnInfo] = [],
        parameters: [ProcedureParameterInfo] = [],
        triggerAction: String? = nil,
        triggerTable: String? = nil,
        comment: String? = nil
    ) {
        self.name = name
        self.schema = schema
        self.type = type
        self.columns = columns
        self.parameters = parameters
        self.triggerAction = triggerAction
        self.triggerTable = triggerTable
        self.comment = comment
    }

    public nonisolated var fullName: String {
        "\(schema).\(name)"
    }

    private enum CodingKeys: String, CodingKey {
        case name, schema, type, columns, parameters, triggerAction, triggerTable, comment
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

        public init(name: String, dataType: String, isNullable: Bool, defaultValue: String?, generatedExpression: String?) {
            self.name = name; self.dataType = dataType; self.isNullable = isNullable; self.defaultValue = defaultValue; self.generatedExpression = generatedExpression
        }
    }

    public struct PrimaryKey: Sendable, Codable, Hashable {
        public var name: String
        public var columns: [String]
        public init(name: String, columns: [String]) { self.name = name; self.columns = columns }
    }

    public struct Index: Identifiable, Sendable, Codable, Hashable {
        public struct Column: Identifiable, Sendable, Codable, Hashable {
            public enum SortOrder: String, Sendable, Codable, Hashable { case ascending, descending }
            public var id: Int { position }
            public var name: String
            public var position: Int
            public var sortOrder: SortOrder
            public init(name: String, position: Int, sortOrder: SortOrder) { self.name = name; self.position = position; self.sortOrder = sortOrder }
        }
        public var id: String { name }
        public var name: String
        public var columns: [Column]
        public var isUnique: Bool
        public var filterCondition: String?
        public init(name: String, columns: [Column], isUnique: Bool, filterCondition: String?) { self.name = name; self.columns = columns; self.isUnique = isUnique; self.filterCondition = filterCondition }
    }

    public struct UniqueConstraint: Identifiable, Sendable, Codable, Hashable {
        public var id: String { name }
        public var name: String
        public var columns: [String]
        public init(name: String, columns: [String]) { self.name = name; self.columns = columns }
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
        public init(name: String, columns: [String], referencedSchema: String, referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?) {
            self.name = name; self.columns = columns; self.referencedSchema = referencedSchema; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns; self.onUpdate = onUpdate; self.onDelete = onDelete
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
        public init(name: String, baseColumns: [String], referencedTable: String, referencedColumns: [String], onUpdate: String?, onDelete: String?) {
            self.name = name; self.baseColumns = baseColumns; self.referencedTable = referencedTable; self.referencedColumns = referencedColumns; self.onUpdate = onUpdate; self.onDelete = onDelete
        }
    }

    public var columns: [Column]
    public var primaryKey: PrimaryKey?
    public var indexes: [Index]
    public var uniqueConstraints: [UniqueConstraint]
    public var foreignKeys: [ForeignKey]
    public var dependencies: [Dependency]

    public init(columns: [Column] = [], primaryKey: PrimaryKey? = nil, indexes: [Index] = [], uniqueConstraints: [UniqueConstraint] = [], foreignKeys: [ForeignKey] = [], dependencies: [Dependency] = []) {
        self.columns = columns; self.primaryKey = primaryKey; self.indexes = indexes; self.uniqueConstraints = uniqueConstraints; self.foreignKeys = foreignKeys; self.dependencies = dependencies
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
    
    public var ratio: Double {
        tableSizeKB > 0 ? (sizeKB / tableSizeKB) * 100 : 0
    }
    
    public var status: String {
        if totalScans == 0 && sizeKB > 1024 {
            return "Unused"
        } else if fragmentationPercent > 30 {
            return "Fragmented"
        } else {
            return "Healthy"
        }
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
        tableSizeKB: Double
    ) {
        self.schemaName = schemaName; self.tableName = tableName; self.indexName = indexName; self.fragmentationPercent = fragmentationPercent; self.pageCount = pageCount; self.indexType = indexType; self.indexId = indexId
        self.isUnique = isUnique; self.isPrimaryKey = isPrimaryKey; self.totalScans = totalScans; self.totalUpdates = totalUpdates; self.sizeKB = sizeKB; self.tableSizeKB = tableSizeKB
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
