import Foundation
import EchoSense

@MainActor
enum EchoSenseBridge {
    private static var cachedSourceHash: Int?
    private static var cachedResult: EchoSenseDatabaseStructure?

    /// Returns a cached EchoSenseDatabaseStructure if the source structure hasn't changed.
    static func makeStructure(from structure: DatabaseStructure) -> EchoSenseDatabaseStructure {
        let sourceHash = structure.hashValue
        if let cached = cachedResult, cachedSourceHash == sourceHash {
            return cached
        }
        let result = buildStructure(from: structure)
        cachedSourceHash = sourceHash
        cachedResult = result
        return result
    }

    private static func buildStructure(from structure: DatabaseStructure) -> EchoSenseDatabaseStructure {
        let databases = structure.databases.map { database -> EchoSenseDatabaseInfo in
            let schemas = database.schemas.map { schema -> EchoSenseSchemaInfo in
                let objects = schema.objects.map { object -> EchoSenseSchemaObjectInfo in
                    let columns = object.columns.map { column -> EchoSenseColumnInfo in
                        let foreignKey = column.foreignKey.map { reference -> EchoSenseForeignKeyReference in
                            EchoSenseForeignKeyReference(constraintName: reference.constraintName,
                                                         referencedSchema: reference.referencedSchema,
                                                         referencedTable: reference.referencedTable,
                                                         referencedColumn: reference.referencedColumn)
                        }
                        return EchoSenseColumnInfo(id: UUID(),
                                                   name: column.name,
                                                   dataType: column.dataType,
                                                   isPrimaryKey: column.isPrimaryKey,
                                                   isNullable: column.isNullable,
                                                   maxLength: column.maxLength,
                                                   foreignKey: foreignKey)
                    }
                    return EchoSenseSchemaObjectInfo(id: UUID(),
                                                     name: object.name,
                                                     schema: object.schema,
                                                     type: EchoSenseSchemaObjectInfo.ObjectType(object.type),
                                                     columns: columns)
                }
                return EchoSenseSchemaInfo(id: UUID(),
                                           name: schema.name,
                                           objects: objects)
            }
            return EchoSenseDatabaseInfo(id: UUID(),
                                         name: database.name,
                                         schemas: schemas)
        }
        return EchoSenseDatabaseStructure(serverVersion: structure.serverVersion,
                                          databases: databases)
    }

}
