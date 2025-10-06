import Foundation

struct ExplorerFocus: Identifiable, Equatable {
    let id = UUID()
    let connectionID: UUID
    let databaseName: String
    let schemaName: String
    let objectName: String
    let objectType: SchemaObjectInfo.ObjectType
    let columnName: String?
}
