import SwiftUI
import EchoSense

extension DatabaseObjectRow {
    internal func executeStatement() -> String {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        switch connection.databaseType {
        case .postgresql:
            if object.type == .procedure {
                return "CALL \(qualified)(/* arguments */);"
            } else {
                return "SELECT * FROM \(qualified)(/* arguments */);"
            }
        case .mysql:
            if object.type == .procedure {
                return "CALL \(qualified)(/* arguments */);"
            } else {
                return "SELECT \(qualified)(/* arguments */);"
            }
        case .microsoftSQL:
            if object.type == .function {
                return "SELECT * FROM \(qualified)(/* arguments */);"
            } else {
                return "EXEC \(qualified) /* arguments */;"
            }
        case .sqlite:
            return "-- Programmable object execution is not supported in SQLite."
        }
    }

    internal func truncateStatement() -> String {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL:
            return "TRUNCATE TABLE \(qualified);"
        case .sqlite:
            return "-- TRUNCATE TABLE is not supported in SQLite."
        }
    }

    internal func renameStatement(newName: String? = nil) -> String? {
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let trimmedName = newName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackName = "<new_name>"
        let effectiveName = trimmedName.flatMap({ $0.isEmpty ? nil : $0 }) ?? fallbackName
        let quotedNewName = quoteIdentifier(effectiveName)

        switch connection.databaseType {
        case .postgresql:
            return renameStatementPostgres(qualified: qualified, quotedNewName: quotedNewName, trimmedName: trimmedName)
        case .mysql:
            return renameStatementMySQL(qualified: qualified, quotedNewName: quotedNewName, effectiveName: effectiveName, trimmedName: trimmedName)
        case .sqlite:
            return renameStatementSQLite(qualified: qualified, quotedNewName: quotedNewName)
        case .microsoftSQL:
            let escaped = effectiveName.replacingOccurrences(of: "'", with: "''")
            return "EXEC sp_rename '\(qualifiedForStoredProcedures())', '\(escaped)';"
        }
    }

    private func renameStatementPostgres(qualified: String, quotedNewName: String, trimmedName: String?) -> String? {
        switch object.type {
        case .table:
            return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
        case .view:
            return "ALTER VIEW \(qualified) RENAME TO \(quotedNewName);"
        case .materializedView:
            return "ALTER MATERIALIZED VIEW \(qualified) RENAME TO \(quotedNewName);"
        case .function:
            return trimmedName == nil
            ? "ALTER FUNCTION \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
            : nil
        case .procedure:
            return trimmedName == nil
            ? "ALTER PROCEDURE \(qualified)(/* arg_types */) RENAME TO \(quotedNewName);"
            : nil
        case .trigger:
            return "ALTER TRIGGER \(quoteIdentifier(object.name)) ON \(triggerTargetName()) RENAME TO \(quotedNewName);"
        case .extension:
            return nil
        }
    }

    private func renameStatementMySQL(qualified: String, quotedNewName: String, effectiveName: String, trimmedName: String?) -> String? {
        switch object.type {
        case .table, .view:
            let destination = qualifiedDestinationName(effectiveName)
            return "RENAME TABLE \(qualified) TO \(destination);"
        case .trigger:
            return "RENAME TRIGGER \(qualified) TO \(quotedNewName);"
        case .function:
            return trimmedName == nil
            ? """
        -- MySQL cannot rename functions directly.
        -- Drop and recreate the function with the desired name.
        """
            : nil
        case .procedure:
            return trimmedName == nil
            ? """
        -- MySQL cannot rename procedures directly.
        -- Drop and recreate the procedure with the desired name.
        """
            : nil
        case .materializedView:
            return "-- Materialized views are not supported in MySQL."
        case .extension:
            return nil
        }
    }

    private func renameStatementSQLite(qualified: String, quotedNewName: String) -> String? {
        switch object.type {
        case .table:
            return "ALTER TABLE \(qualified) RENAME TO \(quotedNewName);"
        case .view:
            return """
        -- SQLite cannot rename views directly.
        -- Drop and recreate the view with the desired name.
        """
        case .trigger, .function, .procedure, .materializedView, .extension:
            return "-- Renaming is not supported for this object in SQLite."
        }
    }

    internal func dropStatement(includeIfExists: Bool) -> String {
        let keyword = objectTypeKeyword()
        let qualified = qualifiedName(schema: object.schema, name: object.name)
        let ifExists = includeIfExists ? dropIfExistsClause() : ""

        switch connection.databaseType {
        case .postgresql:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(quoteIdentifier(object.name)) ON \(triggerTargetName());"
            case .function, .procedure:
                return "DROP FUNCTION \(includeIfExists ? "IF EXISTS " : "")\(qualified)(/* arg_types */);"
            default:
                return "DROP \(keyword) \(ifExists)\(qualified);"
            }
        case .mysql:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
            default:
                return "DROP \(keyword) \(includeIfExists ? "IF EXISTS " : "")\(qualified);"
            }
        case .sqlite:
            return "DROP \(keyword) \(ifExists)\(qualified);"
        case .microsoftSQL:
            switch object.type {
            case .trigger:
                return "DROP TRIGGER \(includeIfExists ? "IF EXISTS " : "")\(qualified) ON \(triggerTargetName());"
            default:
                return "DROP \(keyword) \(ifExists)\(qualified);"
            }
        }
    }

    private func dropIfExistsClause() -> String {
        switch connection.databaseType {
        case .postgresql, .mysql, .microsoftSQL, .sqlite:
            return "IF EXISTS "
        }
    }

    private func qualifiedDestinationName(_ newName: String) -> String {
        let schema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
        let quotedNewName = quoteIdentifier(newName)
        guard !schema.isEmpty, connection.databaseType != .sqlite else {
            return quotedNewName
        }
        return "\(quoteIdentifier(schema)).\(quotedNewName)"
    }

    private func qualifiedForStoredProcedures() -> String {
        let trimmedSchema = object.schema.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedSchema.isEmpty || connection.databaseType == .sqlite {
            return object.name
        }
        return "\(trimmedSchema).\(object.name)"
    }
}
