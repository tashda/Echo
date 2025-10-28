import Foundation

public struct DatabaseStructure: Sendable, Identifiable, Codable, Hashable {
    public var id = UUID()
    public let serverVersion: String?
    public var databases: [DatabaseInfo]

    public nonisolated init(serverVersion: String? = nil, databases: [DatabaseInfo] = []) {
        self.serverVersion = serverVersion
        self.databases = databases
    }
}

public struct DatabaseInfo: Sendable, Identifiable, Codable, Hashable {
    public nonisolated var id: String { name }
    public let name: String
    public var schemas: [SchemaInfo]
    public var schemaCount: Int

    public nonisolated init(name: String, schemas: [SchemaInfo] = [], schemaCount: Int? = nil) {
        self.name = name
        self.schemas = schemas
        self.schemaCount = schemaCount ?? schemas.count
    }
}

public struct SchemaInfo: Sendable, Identifiable, Codable, Hashable {
    public nonisolated var id: String { name }
    public let name: String
    public let objects: [SchemaObjectInfo]

    public nonisolated init(name: String, objects: [SchemaObjectInfo]) {
        self.name = name
        self.objects = objects
    }

    public nonisolated var allObjects: [SchemaObjectInfo] { objects }
    public nonisolated var tables: [SchemaObjectInfo] { objects.filter { $0.type == .table } }
    public nonisolated var views: [SchemaObjectInfo] { objects.filter { $0.type == .view } }
    public nonisolated var materializedViews: [SchemaObjectInfo] { objects.filter { $0.type == .materializedView } }
    public nonisolated var functions: [SchemaObjectInfo] { objects.filter { $0.type == .function } }
    public nonisolated var triggers: [SchemaObjectInfo] { objects.filter { $0.type == .trigger } }
    public nonisolated var procedures: [SchemaObjectInfo] { objects.filter { $0.type == .procedure } }
}

extension SchemaObjectInfo.ObjectType {
    nonisolated static func supported(for databaseType: DatabaseType) -> [SchemaObjectInfo.ObjectType] {
        switch databaseType {
        case .postgresql:
            return [.table, .view, .materializedView, .function, .trigger]
        case .mysql:
            return [.table, .view, .function, .procedure, .trigger]
        case .microsoftSQL:
            return [.table, .view, .function, .procedure, .trigger]
        case .sqlite:
            return [.table, .view]
        }
    }
}
