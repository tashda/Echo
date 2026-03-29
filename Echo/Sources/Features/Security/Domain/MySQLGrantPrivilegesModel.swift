import Foundation

enum MySQLSchemaPrivilege: String, CaseIterable, Identifiable {
    case select = "SELECT"
    case insert = "INSERT"
    case update = "UPDATE"
    case delete = "DELETE"
    case create = "CREATE"
    case alter = "ALTER"
    case drop = "DROP"
    case index = "INDEX"
    case trigger = "TRIGGER"
    case references = "REFERENCES"
    case createView = "CREATE VIEW"
    case showView = "SHOW VIEW"
    case alterRoutine = "ALTER ROUTINE"
    case createRoutine = "CREATE ROUTINE"
    case event = "EVENT"
    case lockTables = "LOCK TABLES"
    case createTemporaryTables = "CREATE TEMPORARY TABLES"
    case execute = "EXECUTE"
    case all = "ALL PRIVILEGES"

    var id: String { rawValue }
}
