import Foundation

enum ExplorerSidebarIdentity {
    static func database(connectionID: UUID, databaseName: String) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)"
    }

    static func object(connectionID: UUID, databaseName: String, objectID: String) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#object#\(objectID)"
    }

    static func pinnedObject(connectionID: UUID, databaseName: String, objectID: String) -> String {
        "\(connectionID.uuidString)#db#\(databaseName)#pinned#\(objectID)"
    }
}
