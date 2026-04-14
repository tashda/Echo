import Foundation

struct GenerateScriptsObject: Sendable, Hashable, Identifiable {
    let schema: String
    let name: String
    let type: SchemaObjectInfo.ObjectType

    var id: String {
        "\(type.rawValue)|\(schema)|\(name)"
    }

    var category: String {
        type.pluralDisplayName
    }

    var qualifiedName: String {
        if schema.isEmpty {
            return name
        }
        return "\(schema).\(name)"
    }

    init(schema: String, name: String, type: SchemaObjectInfo.ObjectType) {
        self.schema = schema
        self.name = name
        self.type = type
    }

    init(_ object: SchemaObjectInfo) {
        self.init(schema: object.schema, name: object.name, type: object.type)
    }
}
