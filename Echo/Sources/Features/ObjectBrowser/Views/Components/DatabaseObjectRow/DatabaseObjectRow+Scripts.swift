import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func openCreateDefinition(insertOrReplace: Bool) {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type
                )
                let adjusted = insertOrReplace ? applyCreateOrReplace(to: definition) : definition
                await MainActor.run {
                    environmentState.openQueryTab(for: session, presetQuery: adjusted)
                }
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
    internal func openCreateTableScript() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task {
            do {
                let details = try await session.session.getTableStructureDetails(
                    schema: object.schema,
                    table: object.name
                )
                let script = makeCreateTableScript(details: details)
                await MainActor.run {
                    environmentState.openQueryTab(for: session, presetQuery: script)
                }
            } catch {
                await MainActor.run {
                    environmentState.lastError = DatabaseError.from(error)
                }
            }
        }
    }
    
    private func applyCreateOrReplace(to definition: String) -> String {
        guard let range = definition.range(of: "CREATE", options: [.caseInsensitive]) else {
            return definition
        }
        let snippet = definition[range]
        if snippet.lowercased().contains("create or replace") {
            return definition
        }
        return definition.replacingCharacters(in: range, with: "CREATE OR REPLACE")
    }
    
    internal func openAlterStatement() {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let statement: String
        switch connection.databaseType {
        case .mysql:
            switch object.type {
            case .function, .procedure:
                statement = "ALTER FUNCTION \(qualified)\n    -- Update characteristics here;\n"
            case .trigger:
                statement = "ALTER TRIGGER \(qualified)\n    -- Update trigger definition here;\n"
            default:
                statement = "ALTER \(objectTypeKeyword()) \(qualified)\n    -- Provide ALTER clauses here;\n"
            }
        case .microsoftSQL:
            statement = """
        ALTER \(objectTypeKeyword()) \(qualified)
        -- Update definition here.
        GO
        """
        case .postgresql, .sqlite:
            statement = """
        -- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE.
        """
        }
        openScriptTab(with: statement)
    }
    
    internal func openAlterTableStatement() {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let statement: String
        switch connection.databaseType {
        case .postgresql, .mysql:
            statement = """
        ALTER TABLE \(qualified)
            ADD COLUMN new_column_name data_type;
        """
        case .microsoftSQL:
            statement = """
        ALTER TABLE \(qualified)
            ADD new_column_name data_type;
        """
        case .sqlite:
            statement = """
        ALTER TABLE \(qualified)
            RENAME COLUMN old_column TO new_column;
        """
        }
        openScriptTab(with: statement)
    }
    
    internal func openDropStatement(includeIfExists: Bool) {
        let statement = dropStatement(includeIfExists: includeIfExists)
        openScriptTab(with: statement)
    }
    
    internal func openSelectScript(limit: Int? = nil) {
        let sql: String
        if object.type == .function || object.type == .procedure {
            sql = executeStatement()
        } else {
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let columns = object.columns.isEmpty ? ["*"] : object.columns.map { quoteIdentifier($0.name) }
            let columnLines = columns.joined(separator: ",\n    ")
            sql = makeSelectStatement(
                qualifiedName: qualified,
                columnLines: columnLines,
                databaseType: connection.databaseType,
                limit: limit
            )
        }
        openScriptTab(with: sql)
    }
    
    internal func openExecuteScript() {
        let sql = executeStatement()
        openScriptTab(with: sql)
    }

    internal func openScriptTab(with sql: String) {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }
    }
}
