import Foundation
import Logging
import SQLServerKit

extension GenerateScriptsWizardViewModel {
    func loadObjects() {
        isLoadingObjects = true
        let db = databaseName
        let session = self.session

        Task { [session, db] in
            do {
                let objects: [GenerateScriptsObject]

                if let deps = session.dependencies {
                    objects = try await deps.listAllObjects(database: db).compactMap { sqlObject in
                        guard let type = Self.objectType(forSQLServerTypeCode: sqlObject.type) else {
                            return nil
                        }
                        return GenerateScriptsObject(schema: sqlObject.schema, name: sqlObject.name, type: type)
                    }
                } else if let metadataSession = session as? any DatabaseMetadataSession {
                    let schemas = try await self.schemaNamesToLoad(using: metadataSession)
                    var loadedObjects: [GenerateScriptsObject] = []
                    for schema in schemas {
                        let schemaInfo = try await metadataSession.loadSchemaInfo(schema, progress: nil)
                        loadedObjects.append(contentsOf: schemaInfo.objects.map(GenerateScriptsObject.init))
                    }
                    objects = loadedObjects
                } else {
                    objects = []
                }

                self.objectsByCategory = GenerateScriptsScriptBuilder.categoryGroups(for: objects)
                self.selectedObjectIDs = GenerateScriptsScriptBuilder.defaultSelection(
                    from: objects,
                    preferredObjectID: self.preferredObjectID
                )
                self.isLoadingObjects = false
            } catch {
                logger.error("Failed to load objects: \(error)")
                self.isLoadingObjects = false
            }
        }
    }

    private func schemaNamesToLoad(using metadataSession: any DatabaseMetadataSession) async throws -> [String] {
        switch databaseType {
        case .mysql:
            return [databaseName]
        case .postgresql:
            return try await metadataSession.listSchemas()
        case .sqlite:
            return ["main"]
        case .microsoftSQL:
            return []
        }
    }

    static func objectType(forSQLServerTypeCode typeCode: String) -> SchemaObjectInfo.ObjectType? {
        switch typeCode {
        case "U": return .table
        case "V": return .view
        case "P": return .procedure
        case "FN", "IF", "TF": return .function
        case "TR": return .trigger
        case "SN": return .synonym
        case "TT": return .type
        case "SO": return .sequence
        default: return nil
        }
    }
}
