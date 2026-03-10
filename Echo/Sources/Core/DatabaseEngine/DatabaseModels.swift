import Foundation

public struct SchemaObjectInfo: Sendable, Identifiable, Codable, Hashable {
    public enum ObjectType: String, Sendable, CaseIterable, Codable {
        case table = "BASE TABLE"
        case view = "VIEW"
        case materializedView = "MATERIALIZED VIEW"
        case function = "FUNCTION"
        case trigger = "TRIGGER"
        case procedure = "PROCEDURE"

        public nonisolated var pluralDisplayName: String {
            switch self {
            case .table: return "Tables"
            case .view: return "Views"
            case .materializedView: return "Materialized Views"
            case .function: return "Functions"
            case .procedure: return "Procedures"
            case .trigger: return "Triggers"
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
