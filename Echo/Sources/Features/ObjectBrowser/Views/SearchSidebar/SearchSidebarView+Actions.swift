import SwiftUI

extension SearchSidebarView {
    func handleResultTap(_ result: GlobalSearchResult, openInNewTab: Bool = false) {
        guard let payload = result.payload else { return }
        guard let session = viewModel.session(for: result.connectionSessionID) else { return }

        let databaseName = result.databaseName

        // Activate the correct connection
        environmentState.sessionGroup.setActiveSession(session.id)

        switch payload {
        case .schemaObject(let schema, let name, let type):
            if openInNewTab, type == .table {
                openQueryPreview(forTable: name, schema: schema, session: session, database: databaseName)
            } else {
                focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: type)
            }

        case .column(let schema, let table, let column):
            if openInNewTab {
                openQueryPreview(forColumn: column, table: table, schema: schema, session: session, database: databaseName)
            } else {
                focusExplorer(on: session, database: databaseName, schema: schema, objectName: table, columnName: column, objectType: .table)
            }

        case .index(let schema, let table, _):
            if openInNewTab {
                openQueryPreview(forTable: table, schema: schema, session: session, database: databaseName)
            } else {
                openStructure(for: session, schema: schema, table: table, focus: .indexes)
            }

        case .foreignKey(let schema, let table, _):
            if openInNewTab {
                openQueryPreview(forTable: table, schema: schema, session: session, database: databaseName)
            } else {
                openStructure(for: session, schema: schema, table: table, focus: .relations)
            }

        case .function(let schema, let name):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: .function)
        case .procedure(let schema, let name):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: .procedure)

        case .trigger(let schema, _, let name):
            focusExplorer(on: session, database: databaseName, schema: schema, objectName: name, columnName: nil, objectType: .trigger)

        case .queryTab(let tabID, let connectionSessionID):
            environmentState.sessionGroup.setActiveSession(connectionSessionID)
            tabStore.activeTabId = tabID
        }
    }

    private func openStructure(for session: ConnectionSession, schema: String, table: String, focus: TableStructureSection?) {
        let object = SchemaObjectInfo(name: table, schema: schema, type: .table)
        environmentState.openStructureTab(for: session, object: object, focus: focus)
    }

    private func openQueryPreview(forTable table: String, schema: String, session: ConnectionSession, database: String) {
        let qualified = qualifiedTableName(schema: schema, table: table, databaseType: session.connection.databaseType)
        let sql: String
        switch session.connection.databaseType {
        case .microsoftSQL:
            sql = "SELECT TOP 200 *\nFROM \(qualified);"
        default:
            sql = "SELECT *\nFROM \(qualified)\nLIMIT 200;"
        }
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }

    private func openQueryPreview(forColumn column: String, table: String, schema: String, session: ConnectionSession, database: String) {
        let databaseType = session.connection.databaseType
        let qualified = qualifiedTableName(schema: schema, table: table, databaseType: databaseType)
        let quotedColumn = quoteIdentifier(column, databaseType: databaseType)
        let sql: String
        switch databaseType {
        case .microsoftSQL:
            sql = "SELECT TOP 200 \(quotedColumn)\nFROM \(qualified);"
        default:
            sql = "SELECT \(quotedColumn)\nFROM \(qualified)\nLIMIT 200;"
        }
        environmentState.openQueryTab(for: session, presetQuery: sql, database: database)
    }

    private func qualifiedTableName(schema: String, table: String, databaseType: DatabaseType) -> String {
        let tablePart = quoteIdentifier(table, databaseType: databaseType)
        let normalizedSchema = schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedSchema.isEmpty || databaseType == .sqlite {
            return tablePart
        }
        let schemaPart = quoteIdentifier(normalizedSchema, databaseType: databaseType)
        return "\(schemaPart).\(tablePart)"
    }

    private func quoteIdentifier(_ identifier: String, databaseType: DatabaseType) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        switch databaseType {
        case .mysql:
            let escaped = trimmed.replacingOccurrences(of: "`", with: "``")
            return "`\(escaped)`"
        case .microsoftSQL:
            let escaped = trimmed.replacingOccurrences(of: "]", with: "]]")
            return "[\(escaped)]"
        default:
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
    }

    private func focusExplorer(
        on session: ConnectionSession,
        database: String,
        schema: String,
        objectName: String,
        columnName: String?,
        objectType: SchemaObjectInfo.ObjectType = .table
    ) {
        let focus = ExplorerFocus(
            connectionID: session.connection.id,
            databaseName: database,
            schemaName: schema,
            objectName: objectName,
            objectType: objectType,
            columnName: columnName
        )
        navigationStore.focusExplorer(focus)
    }

    private func openDefinition(for objectName: String, schema: String, type: SchemaObjectInfo.ObjectType, in session: ConnectionSession, database: String) {
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: objectName,
                    schemaName: schema,
                    objectType: type
                )
                await MainActor.run {
                    environmentState.openQueryTab(for: session, presetQuery: definition, database: database)
                }
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                }
            }
        }
    }
}
