import AppKit
import SwiftUI
import SQLServerKit

/// What the object menus run: scripts, definitions and the visual designers.
extension ObjectBrowserSidebarView {
    func openNewObjectInDesigner(type: SchemaObjectInfo.ObjectType, session: ConnectionSession) {
        let connID = session.connection.id
        let schema = session.connection.databaseType == .microsoftSQL ? "dbo" : "public"

        switch type {
        case .view:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingView: nil,
                isMaterialized: false
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .materializedView:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingView: nil,
                isMaterialized: true
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .function:
            let value = environmentState.prepareFunctionEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingFunction: nil
            )
            openWindow(id: FunctionEditorWindow.sceneID, value: value)
        case .trigger:
            let value = environmentState.prepareTriggerEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                tableName: "",
                existingTrigger: nil
            )
            openWindow(id: TriggerEditorWindow.sceneID, value: value)
        case .sequence:
            let value = environmentState.prepareSequenceEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingSequence: nil
            )
            openWindow(id: SequenceEditorWindow.sceneID, value: value)
        case .type:
            let value = environmentState.prepareTypeEditorWindow(
                connectionSessionID: connID,
                schemaName: schema,
                existingType: nil,
                typeCategory: .composite
            )
            openWindow(id: TypeEditorWindow.sceneID, value: value)
        default:
            break
        }
    }

    func performScriptAction(
        _ action: ScriptAction,
        object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession
    ) {
        let databaseType = session.connection.databaseType
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        let sql: String

        switch action {
        case .select:
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: "*",
                databaseType: databaseType,
                limit: nil
            )
        case .selectLimited(let limit):
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: "*",
                databaseType: databaseType,
                limit: limit
            )
        case .create:
            openDefinition(for: object, databaseName: databaseName, session: session, replaceCreateWith: nil)
            return
        case .createOrReplace:
            openDefinition(for: object, databaseName: databaseName, session: session, replaceCreateWith: "CREATE OR REPLACE")
            return
        case .alter:
            openAlterDefinition(for: object, databaseName: databaseName, session: session)
            return
        case .alterTable:
            sql = "ALTER TABLE \(qualified)\n    ADD new_column_name data_type;"
        case .insert:
            sql = "INSERT INTO \(qualified) (column1, column2)\nVALUES (value1, value2);"
        case .update:
            sql = "UPDATE \(qualified)\nSET column1 = value1\nWHERE condition;"
        case .delete:
            sql = "DELETE FROM \(qualified)\nWHERE condition;"
        case .execute:
            sql = executeStatement(for: object, databaseType: databaseType)
        case .drop:
            sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: false)
        case .dropIfExists:
            sql = dropStatement(for: object, databaseType: databaseType, includeIfExists: true)
        }

        environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
    }

    func openDefinition(
        for object: SchemaObjectInfo,
        databaseName: String,
        session: ConnectionSession,
        replaceCreateWith replacement: String? = nil
    ) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type,
                    database: databaseName
                )
                if let replacement,
                   let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: replacement)
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: databaseName)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    func openAlterDefinition(for object: SchemaObjectInfo, databaseName: String, session: ConnectionSession) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type,
                    database: databaseName
                )
                if let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: "ALTER")
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: databaseName)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    func openObjectInDesigner(_ object: SchemaObjectInfo, session: ConnectionSession) {
        switch object.type {
        case .view:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingView: object.name,
                isMaterialized: false
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .materializedView:
            let value = environmentState.prepareViewEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingView: object.name,
                isMaterialized: true
            )
            openWindow(id: ViewEditorWindow.sceneID, value: value)
        case .trigger:
            let value = environmentState.prepareTriggerEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                tableName: object.triggerTable ?? "",
                existingTrigger: object.name
            )
            openWindow(id: TriggerEditorWindow.sceneID, value: value)
        case .function:
            let value = environmentState.prepareFunctionEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingFunction: object.name
            )
            openWindow(id: FunctionEditorWindow.sceneID, value: value)
        case .sequence:
            let value = environmentState.prepareSequenceEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingSequence: object.name
            )
            openWindow(id: SequenceEditorWindow.sceneID, value: value)
        case .type:
            let value = environmentState.prepareTypeEditorWindow(
                connectionSessionID: session.connection.id,
                schemaName: object.schema,
                existingType: object.name,
                typeCategory: .composite
            )
            openWindow(id: TypeEditorWindow.sceneID, value: value)
        default:
            break
        }
    }

    func previewQuery(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        TablePreviewQuery.sql(schema: object.schema, table: object.name, databaseType: databaseType)
    }

    func executeStatement(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        return switch databaseType {
        case .microsoftSQL:
            "EXEC \(qualified);"
        case .postgresql:
            "SELECT * FROM \(qualified)();"
        case .mysql, .sqlite:
            "CALL \(qualified)();"
        }
    }

    func dropStatement(for object: SchemaObjectInfo, databaseType: DatabaseType, includeIfExists: Bool) -> String {
        let qualified = qualifiedName(for: object, databaseType: databaseType)
        let keyword: String = switch object.type {
        case .table: "TABLE"
        case .view: "VIEW"
        case .materializedView: "MATERIALIZED VIEW"
        case .function: "FUNCTION"
        case .procedure: "PROCEDURE"
        case .trigger: "TRIGGER"
        case .extension: "EXTENSION"
        case .sequence: "SEQUENCE"
        case .type: "TYPE"
        case .synonym: "SYNONYM"
        }
        let ifExists = includeIfExists ? " IF EXISTS" : ""
        return "DROP \(keyword)\(ifExists) \(qualified);"
    }

    func qualifiedName(for object: SchemaObjectInfo, databaseType: DatabaseType) -> String {
        switch databaseType {
        case .microsoftSQL:
            "[\(object.schema)].[\(object.name)]"
        case .postgresql:
            "\"\(object.schema.replacingOccurrences(of: "\"", with: "\"\""))\".\"\(object.name.replacingOccurrences(of: "\"", with: "\"\""))\""
        case .mysql:
            "`\(object.schema)`.`\(object.name)`"
        case .sqlite:
            "\"\(object.name.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }
}

