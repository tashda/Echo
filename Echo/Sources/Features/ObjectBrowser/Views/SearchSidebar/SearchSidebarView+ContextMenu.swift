import SwiftUI
import AppKit

extension SearchSidebarView {

    @ViewBuilder
    func searchResultContextMenu(for result: GlobalSearchResult) -> some View {
        if let payload = result.payload {
            let session = viewModel.session(for: result.connectionSessionID)
            let databaseType = result.databaseType
            let database = result.databaseName

            switch payload {
            case .schemaObject(let schema, let name, let type):
                objectContextMenu(
                    schema: schema, name: name, type: type,
                    result: result, session: session,
                    databaseType: databaseType, database: database
                )

            case .column(let schema, let table, let column):
                columnContextMenu(
                    schema: schema, table: table, column: column,
                    result: result, session: session,
                    databaseType: databaseType, database: database
                )

            case .function(let schema, let name):
                objectContextMenu(
                    schema: schema, name: name, type: .function,
                    result: result, session: session,
                    databaseType: databaseType, database: database
                )

            case .procedure(let schema, let name):
                objectContextMenu(
                    schema: schema, name: name, type: .procedure,
                    result: result, session: session,
                    databaseType: databaseType, database: database
                )

            case .trigger(let schema, _, let name):
                objectContextMenu(
                    schema: schema, name: name, type: .trigger,
                    result: result, session: session,
                    databaseType: databaseType, database: database
                )

            case .index(let schema, let table, _):
                Button("Show in Explorer") { handleResultTap(result) }
                Button("Open Table Structure") {
                    guard let session else { return }
                    let object = SchemaObjectInfo(name: table, schema: schema, type: .table)
                    environmentState.openStructureTab(for: session, object: object, focus: .indexes)
                }
                copyNameButton(name: "\(schema).\(table)")

            case .foreignKey(let schema, let table, _):
                Button("Show in Explorer") { handleResultTap(result) }
                Button("Open Table Structure") {
                    guard let session else { return }
                    let object = SchemaObjectInfo(name: table, schema: schema, type: .table)
                    environmentState.openStructureTab(for: session, object: object, focus: .relations)
                }
                copyNameButton(name: "\(schema).\(table)")

            case .queryTab:
                Button("Switch to Tab") { handleResultTap(result) }
            }
        }
    }

    // MARK: - Object Context Menu (Tables, Views, Functions, Procedures, Triggers)

    @ViewBuilder
    private func objectContextMenu(
        schema: String, name: String, type: SchemaObjectInfo.ObjectType,
        result: GlobalSearchResult, session: ConnectionSession?,
        databaseType: DatabaseType, database: String
    ) -> some View {
        Button("Show in Explorer") { handleResultTap(result) }

        if type == .table || type == .view || type == .materializedView {
            Button("Open Data") {
                guard let session else { return }
                environmentState.openTableDataTab(for: session, schema: schema, table: name, databaseName: database)
            }
        }

        if type == .view || type == .materializedView || type == .function || type == .procedure || type == .trigger {
            Button("View Definition") {
                guard let session else { return }
                openDefinition(objectName: name, schema: schema, type: type, session: session, database: database)
            }
        }

        Divider()

        let scriptActions = ScriptActionResolver.actions(for: type, databaseType: databaseType)
        if !scriptActions.isEmpty {
            Menu("Script as") {
                ScriptAsMenuContent(
                    actions: scriptActions,
                    databaseType: databaseType
                ) { action in
                    guard let session else { return }
                    performScriptAction(action, schema: schema, name: name, type: type, session: session, databaseType: databaseType, database: database)
                }
            }
        }

        Divider()

        copyNameButton(name: qualifiedName(schema: schema, name: name, databaseType: databaseType))
    }

    // MARK: - Column Context Menu

    @ViewBuilder
    private func columnContextMenu(
        schema: String, table: String, column: String,
        result: GlobalSearchResult, session: ConnectionSession?,
        databaseType: DatabaseType, database: String
    ) -> some View {
        Button("Show in Explorer") { handleResultTap(result) }

        Button("Open Table Data") {
            guard let session else { return }
            environmentState.openTableDataTab(for: session, schema: schema, table: table, databaseName: database)
        }

        Divider()

        Button("Script SELECT Column") {
            guard let session else { return }
            let qTable = qualifiedName(schema: schema, name: table, databaseType: databaseType)
            let qCol = quoteIdentifier(column, databaseType: databaseType)
            let sql = databaseType == .microsoftSQL
                ? "SELECT TOP 200 \(qCol)\nFROM \(qTable);"
                : "SELECT \(qCol)\nFROM \(qTable)\nLIMIT 200;"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
        }

        Divider()

        copyNameButton(name: column)
    }

    // MARK: - Script Action Execution

    private func performScriptAction(
        _ action: ScriptAction,
        schema: String, name: String, type: SchemaObjectInfo.ObjectType,
        session: ConnectionSession, databaseType: DatabaseType, database: String
    ) {
        let qualified = qualifiedName(schema: schema, name: name, databaseType: databaseType)

        switch action {
        case .select:
            let sql = type == .function || type == .procedure
                ? executeStatement(schema: schema, name: name, databaseType: databaseType)
                : makeSelectStatement(qualified: qualified, databaseType: databaseType, limit: nil)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .selectLimited(let limit):
            let sql = makeSelectStatement(qualified: qualified, databaseType: databaseType, limit: limit)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .create:
            openCreateScript(schema: schema, name: name, type: type, session: session, database: database, insertOrReplace: false)

        case .createOrReplace:
            openCreateScript(schema: schema, name: name, type: type, session: session, database: database, insertOrReplace: true)

        case .alter:
            openAlterScript(schema: schema, name: name, type: type, session: session, databaseType: databaseType, database: database)

        case .alterTable:
            let sql = "ALTER TABLE \(qualified)\n    ADD new_column_name data_type;"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .insert:
            let sql = "INSERT INTO \(qualified) (column1, column2)\nVALUES (value1, value2);"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .update:
            let sql = "UPDATE \(qualified)\nSET column1 = value1\nWHERE condition;"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .delete:
            let sql = "DELETE FROM \(qualified)\nWHERE condition;"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .execute:
            let sql = executeStatement(schema: schema, name: name, databaseType: databaseType)
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .drop:
            let keyword = objectTypeKeyword(type)
            let sql = "DROP \(keyword) \(qualified);"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)

        case .dropIfExists:
            let keyword = objectTypeKeyword(type)
            let sql = databaseType == .microsoftSQL
                ? "DROP \(keyword) IF EXISTS \(qualified);"
                : "DROP \(keyword) IF EXISTS \(qualified);"
            environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
        }
    }

    // MARK: - Script Helpers

    private func openCreateScript(schema: String, name: String, type: SchemaObjectInfo.ObjectType, session: ConnectionSession, database: String, insertOrReplace: Bool) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: name, schemaName: schema, objectType: type, database: database
                )
                if insertOrReplace, definition.range(of: "CREATE OR REPLACE", options: .caseInsensitive) == nil,
                   let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: "CREATE OR REPLACE")
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: database)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    private func openAlterScript(schema: String, name: String, type: SchemaObjectInfo.ObjectType, session: ConnectionSession, databaseType: DatabaseType, database: String) {
        Task {
            do {
                var definition = try await session.session.getObjectDefinition(
                    objectName: name, schemaName: schema, objectType: type, database: database
                )
                if let range = definition.range(of: "CREATE", options: .caseInsensitive) {
                    definition = definition.replacingCharacters(in: range, with: "ALTER")
                }
                environmentState.openQueryTab(for: session, presetQuery: definition, database: database)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    private func openDefinition(objectName: String, schema: String, type: SchemaObjectInfo.ObjectType, session: ConnectionSession, database: String) {
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: objectName, schemaName: schema, objectType: type, database: database
                )
                environmentState.openQueryTab(for: session, presetQuery: definition, database: database)
            } catch {
                environmentState.lastError = DatabaseError.from(error)
            }
        }
    }

    private func makeSelectStatement(qualified: String, databaseType: DatabaseType, limit: Int?) -> String {
        if let limit {
            return databaseType == .microsoftSQL
                ? "SELECT TOP \(limit) *\nFROM \(qualified);"
                : "SELECT *\nFROM \(qualified)\nLIMIT \(limit);"
        }
        return "SELECT *\nFROM \(qualified);"
    }

    private func executeStatement(schema: String, name: String, databaseType: DatabaseType) -> String {
        let qualified = qualifiedName(schema: schema, name: name, databaseType: databaseType)
        switch databaseType {
        case .microsoftSQL:
            return "EXEC \(qualified);"
        case .postgresql:
            return "SELECT * FROM \(qualified)();"
        default:
            return "CALL \(qualified)();"
        }
    }

    private func objectTypeKeyword(_ type: SchemaObjectInfo.ObjectType) -> String {
        switch type {
        case .table: return "TABLE"
        case .view: return "VIEW"
        case .materializedView: return "MATERIALIZED VIEW"
        case .function: return "FUNCTION"
        case .procedure: return "PROCEDURE"
        case .trigger: return "TRIGGER"
        case .extension: return "EXTENSION"
        case .sequence: return "SEQUENCE"
        case .type: return "TYPE"
        case .synonym: return "SYNONYM"
        }
    }

    // MARK: - Shared Helpers

    private func copyNameButton(name: String) -> some View {
        Button("Copy Name") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(name, forType: .string)
        }
    }

    private func qualifiedName(schema: String, name: String, databaseType: DatabaseType) -> String {
        let trimmed = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || databaseType == .sqlite {
            return quoteIdentifier(name, databaseType: databaseType)
        }
        return "\(quoteIdentifier(trimmed, databaseType: databaseType)).\(quoteIdentifier(name, databaseType: databaseType))"
    }

    private func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        switch databaseType {
        case .mysql:
            return "`\(trimmed.replacingOccurrences(of: "`", with: "``"))`"
        case .microsoftSQL:
            return "[\(trimmed.replacingOccurrences(of: "]", with: "]]"))]"
        default:
            return "\"\(trimmed.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
    }
}
