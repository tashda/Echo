import Foundation

public struct DatabaseStructure: Identifiable, Codable, Hashable {
    public var id = UUID()
    public let serverVersion: String?
    public var databases: [DatabaseInfo]

    public init(serverVersion: String? = nil, databases: [DatabaseInfo] = []) {
        self.serverVersion = serverVersion
        self.databases = databases
    }
}

public struct DatabaseInfo: Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public var schemas: [SchemaInfo]
    public var schemaCount: Int

    public init(name: String, schemas: [SchemaInfo] = [], schemaCount: Int? = nil) {
        self.name = name
        self.schemas = schemas
        self.schemaCount = schemaCount ?? schemas.count
    }
}

public struct SchemaInfo: Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let objects: [SchemaObjectInfo]

    public init(name: String, objects: [SchemaObjectInfo]) {
        self.name = name
        self.objects = objects
    }

    public var allObjects: [SchemaObjectInfo] { objects }
    public var tables: [SchemaObjectInfo] { objects.filter { $0.type == .table } }
    public var views: [SchemaObjectInfo] { objects.filter { $0.type == .view } }
    public var materializedViews: [SchemaObjectInfo] { objects.filter { $0.type == .materializedView } }
    public var functions: [SchemaObjectInfo] { objects.filter { $0.type == .function } }
    public var triggers: [SchemaObjectInfo] { objects.filter { $0.type == .trigger } }
    public var procedures: [SchemaObjectInfo] { objects.filter { $0.type == .procedure } }
}
