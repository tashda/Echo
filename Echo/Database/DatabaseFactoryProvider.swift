import Foundation

struct DatabaseFactoryProvider {
    static func makeFactory(for type: DatabaseType) -> DatabaseFactory? {
        switch type {
        case .postgresql:
            return PostgresNIOFactory()
        case .mysql:
            return MySQLNIOFactory()
        case .sqlite:
            return SQLiteFactory()
        case .microsoftSQL:
            return nil
        }
    }
}
