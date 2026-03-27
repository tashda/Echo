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
                    objectType: object.type,
                    database: databaseName
                )
                let adjusted = insertOrReplace ? applyCreateOrReplace(to: definition) : definition
                environmentState.openQueryTab(for: session, presetQuery: adjusted, database: databaseName)
            } catch {
                environmentState.notificationEngine?.post(
                    category: .generalError,
                    message: "Failed to script \(object.name): \(error.localizedDescription)"
                )
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
                environmentState.openQueryTab(for: session, presetQuery: script, database: databaseName)
            } catch {
                environmentState.notificationEngine?.post(
                    category: .generalError,
                    message: "Failed to script \(object.name): \(error.localizedDescription)"
                )
            }
        }
    }

    private func applyCreateOrReplace(to definition: String) -> String {
        if definition.range(of: "CREATE OR REPLACE", options: [.caseInsensitive]) != nil {
            return definition
        }
        guard let range = definition.range(of: "CREATE", options: [.caseInsensitive]) else {
            return definition
        }
        return definition.replacingCharacters(in: range, with: "CREATE OR REPLACE")
    }

    internal func openAlterStatement() {
        switch connection.databaseType {
        case .microsoftSQL:
            openAlterDefinition()
        case .mysql:
            let qualified = qualifiedName(schema: object.schema, name: object.name)
            let statement: String
            switch object.type {
            case .function, .procedure:
                statement = "ALTER FUNCTION \(qualified)\n    -- Update characteristics here;\n"
            case .trigger:
                statement = "ALTER TRIGGER \(qualified)\n    -- Update trigger definition here;\n"
            default:
                statement = "ALTER \(objectTypeKeyword()) \(qualified)\n    -- Provide ALTER clauses here;\n"
            }
            openScriptTab(with: statement)
        case .postgresql, .sqlite:
            let statement = "-- ALTER is not directly supported for this object. Consider using CREATE OR REPLACE."
            openScriptTab(with: statement)
        }
    }

    private func openAlterDefinition() {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task {
            do {
                let definition = try await session.session.getObjectDefinition(
                    objectName: object.name,
                    schemaName: object.schema,
                    objectType: object.type,
                    database: databaseName
                )
                let altered = applyAlter(to: definition)
                environmentState.openQueryTab(for: session, presetQuery: altered, database: databaseName)
            } catch {
                environmentState.notificationEngine?.post(
                    category: .generalError,
                    message: "Failed to script \(object.name): \(error.localizedDescription)"
                )
            }
        }
    }

    private func applyAlter(to definition: String) -> String {
        guard let range = definition.range(of: "CREATE", options: [.caseInsensitive]) else {
            return definition
        }
        return definition.replacingCharacters(in: range, with: "ALTER")
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

    internal func openInsertScript() {
        let sql = insertStatement()
        openScriptTab(with: sql)
    }

    internal func openUpdateScript() {
        let sql = updateStatement()
        openScriptTab(with: sql)
    }

    internal func openDeleteScript() {
        let sql = deleteStatement()
        openScriptTab(with: sql)
    }

    internal func openModifyScript() {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let sql: String
        switch connection.databaseType {
        case .microsoftSQL:
            let keyword = object.type == .procedure ? "PROCEDURE" : "FUNCTION"
            sql = "ALTER \(keyword) \(qualified)\nAS\n-- Modify \(keyword.lowercased()) here\nGO"
        case .postgresql:
            if object.type == .procedure {
                sql = """
                CREATE OR REPLACE PROCEDURE \(qualified)(/* parameters */)
                LANGUAGE plpgsql
                AS $$
                BEGIN
                    -- Modify procedure here
                END;
                $$;
                """
            } else {
                sql = """
                CREATE OR REPLACE FUNCTION \(qualified)(/* parameters */)
                RETURNS void
                LANGUAGE plpgsql
                AS $$
                BEGIN
                    -- Modify function here
                END;
                $$;
                """
            }
        case .mysql:
            let keyword = object.type == .procedure ? "PROCEDURE" : "FUNCTION"
            sql = "ALTER \(keyword) \(qualified)\n    -- Update characteristics here;\n"
        case .sqlite:
            sql = "-- Modifying programmable objects is not supported in SQLite."
        }
        openScriptTab(with: sql)
    }

    internal func openScriptTab(with sql: String) {
        guard let session = environmentState.sessionGroup.sessionForConnection(connection.id) else { return }
        Task { @MainActor in
            environmentState.openQueryTab(for: session, presetQuery: sql, database: databaseName)
        }
    }
}
