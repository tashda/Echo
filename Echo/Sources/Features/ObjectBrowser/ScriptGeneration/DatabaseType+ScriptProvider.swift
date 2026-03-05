import Foundation

extension DatabaseType {
    var scriptProvider: DatabaseScriptProvider {
        switch self {
        case .postgresql: return PostgresScriptProvider()
        case .mysql: return MySQLScriptProvider()
        case .sqlite: return SQLiteScriptProvider()
        case .microsoftSQL: return MSSQLScriptProvider()
        }
    }
}
