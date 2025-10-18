import Foundation

public enum EchoSenseDatabaseType: String, Codable, CaseIterable, Sendable {
    case postgresql
    case mysql
    case sqlite
    case microsoftSQL
}

public struct EchoSenseDatabaseStructure: Codable, Equatable, Sendable {
    public var serverVersion: String?
    public var databases: [EchoSenseDatabaseInfo]

    public init(serverVersion: String? = nil,
                databases: [EchoSenseDatabaseInfo]) {
        self.serverVersion = serverVersion
        self.databases = databases
    }
}

public struct EchoSenseDatabaseInfo: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var schemas: [EchoSenseSchemaInfo]

    public init(id: UUID = UUID(),
                name: String,
                schemas: [EchoSenseSchemaInfo]) {
        self.id = id
        self.name = name
        self.schemas = schemas
    }
}

public struct EchoSenseSchemaInfo: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var objects: [EchoSenseSchemaObjectInfo]

    public init(id: UUID = UUID(),
                name: String,
                objects: [EchoSenseSchemaObjectInfo]) {
        self.id = id
        self.name = name
        self.objects = objects
    }
}

public struct EchoSenseSchemaObjectInfo: Codable, Equatable, Sendable {
    public enum ObjectType: String, Codable, Sendable {
        case table
        case view
        case materializedView
        case function
        case trigger
    }

    public var id: UUID
    public var name: String
    public var schema: String
    public var type: ObjectType
    public var columns: [EchoSenseColumnInfo]

    public init(id: UUID = UUID(),
                name: String,
                schema: String,
                type: ObjectType,
                columns: [EchoSenseColumnInfo]) {
        self.id = id
        self.name = name
        self.schema = schema
        self.type = type
        self.columns = columns
    }
}

public struct EchoSenseColumnInfo: Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var dataType: String
    public var isPrimaryKey: Bool
    public var isNullable: Bool
    public var maxLength: Int?
    public var foreignKey: EchoSenseForeignKeyReference?

    public init(id: UUID = UUID(),
                name: String,
                dataType: String,
                isPrimaryKey: Bool = false,
                isNullable: Bool = true,
                maxLength: Int? = nil,
                foreignKey: EchoSenseForeignKeyReference? = nil) {
        self.id = id
        self.name = name
        self.dataType = dataType
        self.isPrimaryKey = isPrimaryKey
        self.isNullable = isNullable
        self.maxLength = maxLength
        self.foreignKey = foreignKey
    }
}

public struct EchoSenseForeignKeyReference: Codable, Equatable, Sendable {
    public var constraintName: String
    public var referencedSchema: String
    public var referencedTable: String
    public var referencedColumn: String

    public init(constraintName: String,
                referencedSchema: String,
                referencedTable: String,
                referencedColumn: String) {
        self.constraintName = constraintName
        self.referencedSchema = referencedSchema
        self.referencedTable = referencedTable
        self.referencedColumn = referencedColumn
    }
}
