import Foundation

/// Central factory that creates the correct dialect strategy for each editor and database type.
/// Returns nil when no visual editor is available for the combination.
enum ObjectEditorDialectFactory {

    static func viewDialect(for databaseType: DatabaseType) -> (any ViewEditorDialect)? {
        switch databaseType {
        case .postgresql: PostgresViewDialect()
        case .microsoftSQL: MSSQLViewDialect()
        default: nil
        }
    }

    static func functionDialect(for databaseType: DatabaseType) -> (any FunctionEditorDialect)? {
        switch databaseType {
        case .postgresql: PostgresFunctionDialect()
        case .microsoftSQL: MSSQLFunctionDialect()
        default: nil
        }
    }

    static func triggerDialect(for databaseType: DatabaseType) -> (any TriggerEditorDialect)? {
        switch databaseType {
        case .postgresql: PostgresTriggerDialect()
        case .microsoftSQL: MSSQLTriggerDialect()
        default: nil
        }
    }

    static func sequenceDialect(for databaseType: DatabaseType) -> (any SequenceEditorDialect)? {
        switch databaseType {
        case .postgresql: PostgresSequenceDialect()
        case .microsoftSQL: MSSQLSequenceDialect()
        default: nil
        }
    }

    static func typeDialect(for databaseType: DatabaseType) -> (any TypeEditorDialect)? {
        switch databaseType {
        case .postgresql: PostgresTypeDialect()
        case .microsoftSQL: MSSQLTypeDialect()
        default: nil
        }
    }
}
