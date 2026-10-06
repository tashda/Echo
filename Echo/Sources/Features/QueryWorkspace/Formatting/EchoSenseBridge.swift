import Foundation
import EchoSense

@MainActor
enum EchoSenseBridge {
    private static let cacheLimit = 8
    private static var cachedStructures: [Int: EchoSenseDatabaseStructure] = [:]
    private static var cacheOrder: [Int] = []
    /// Each structure's databases as they were last converted. A structure changes whenever one of
    /// its databases does (a server's schemas arrive one at a time, in the background), and only
    /// that database is converted again.
    private static var convertedDatabases: [UUID: [String: ConvertedDatabase]] = [:]
    private static var convertedOrder: [UUID] = []

    private struct ConvertedDatabase {
        let source: DatabaseInfo
        let converted: EchoSenseDatabaseInfo
    }

    /// Returns a cached EchoSenseDatabaseStructure if the source structure hasn't changed.
    static func makeStructure(from structure: DatabaseStructure) -> EchoSenseDatabaseStructure {
        let sourceHash = structure.hashValue
        if let cached = cachedStructures[sourceHash] {
            touchCacheEntry(for: sourceHash)
            return cached
        }
        let result = buildStructure(from: structure)
        cachedStructures[sourceHash] = result
        touchCacheEntry(for: sourceHash)
        trimCacheIfNeeded()
        return result
    }

    private static func buildStructure(from structure: DatabaseStructure) -> EchoSenseDatabaseStructure {
        let previous = convertedDatabases[structure.id] ?? [:]
        var current: [String: ConvertedDatabase] = [:]
        current.reserveCapacity(structure.databases.count)
        let databases = structure.databases.map { database -> EchoSenseDatabaseInfo in
            if let known = previous[database.name], known.source == database {
                current[database.name] = known
                return known.converted
            }
            let converted = convert(database)
            current[database.name] = ConvertedDatabase(source: database, converted: converted)
            return converted
        }
        convertedDatabases[structure.id] = current
        convertedOrder.removeAll { $0 == structure.id }
        convertedOrder.append(structure.id)
        while convertedOrder.count > cacheLimit {
            convertedDatabases.removeValue(forKey: convertedOrder.removeFirst())
        }
        return EchoSenseDatabaseStructure(serverVersion: structure.serverVersion,
                                          databases: databases)
    }

    private static func convert(_ database: DatabaseInfo) -> EchoSenseDatabaseInfo {
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

    private static func touchCacheEntry(for sourceHash: Int) {
        cacheOrder.removeAll { $0 == sourceHash }
        cacheOrder.append(sourceHash)
    }

    private static func trimCacheIfNeeded() {
        while cacheOrder.count > cacheLimit {
            let evictedHash = cacheOrder.removeFirst()
            cachedStructures.removeValue(forKey: evictedHash)
        }
    }
}
