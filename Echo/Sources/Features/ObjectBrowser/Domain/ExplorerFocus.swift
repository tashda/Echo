import Foundation

struct ExplorerFocus: Identifiable, Equatable {
    let connectionID: UUID
    let databaseName: String
    let schemaName: String
    let objectName: String
    let objectType: SchemaObjectInfo.ObjectType
    let columnName: String?

    var id: String {
        [
            connectionID.uuidString,
            databaseName,
            schemaName,
            objectName,
            objectType.rawValue,
            columnName ?? ""
        ].joined(separator: "|")
    }
}
