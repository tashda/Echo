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
    public var extensions: [SchemaObjectInfo]
    public var schemaCount: Int
    /// Database state (e.g. "ONLINE", "OFFLINE"). Nil for engines that don't report state.
    public var stateDescription: String?

    public nonisolated init(name: String, schemas: [SchemaInfo] = [], extensions: [SchemaObjectInfo] = [], schemaCount: Int? = nil, stateDescription: String? = nil) {
        self.name = name
        self.schemas = schemas
        self.extensions = extensions
        self.schemaCount = schemaCount ?? schemas.count
        self.stateDescription = stateDescription
    }

    /// Whether the database is online (or assumed online when state is unknown).
    public nonisolated var isOnline: Bool {
        guard let state = stateDescription else { return true }
        return state.uppercased() == "ONLINE"
    }
}

public struct AvailableExtensionInfo: Sendable, Identifiable, Codable, Hashable {
    public var id: String { name }
    public let name: String
    public let defaultVersion: String
    public let installedVersion: String?
    public let comment: String?

    public init(name: String, defaultVersion: String, installedVersion: String?, comment: String?) {
        self.name = name
        self.defaultVersion = defaultVersion
        self.installedVersion = installedVersion
        self.comment = comment
    }
}

public struct ExtensionObjectInfo: Sendable, Identifiable, Codable, Hashable {
    public var id: String { "\(schema).\(name)" }
    public let schema: String
    public let name: String
    public let type: String

    public init(schema: String, name: String, type: String) {
        self.schema = schema
        self.name = name
        self.type = type
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
            return [.table, .view, .materializedView, .function, .trigger, .extension]
        case .mysql:
            return [.table, .view, .function, .procedure, .trigger]
        case .microsoftSQL:
            return [.table, .view, .function, .procedure, .trigger]
        case .sqlite:
            return [.table, .view]
        }
    }
}
