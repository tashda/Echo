import Foundation

enum DatabaseType: String, Codable, CaseIterable {
    case postgresql = "postgresql"
    case mysql = "mysql"
    case microsoftSQL = "mssql"
    case sqlite = "sqlite"

    var displayName: String {
        switch self {
        case .postgresql:
            return "PostgreSQL"
        case .mysql:
            return "MySQL"
        case .microsoftSQL:
            return "Microsoft SQL Server"
        case .sqlite:
            return "SQLite"
        }
    }

    var iconName: String {
        switch self {
        case .postgresql:
            return "cylinder.split.1x2"
        case .mysql:
            return "cylinder.split.1x2"
        case .microsoftSQL:
            return "cylinder.split.1x2"
        case .sqlite:
            return "internaldrive"
        }
    }

    var defaultPort: Int {
        switch self {
        case .postgresql:
            return 5432
        case .mysql:
            return 3306
        case .microsoftSQL:
            return 1433
        case .sqlite:
            return 0
        }
    }
}

struct SavedConnection: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var keychainIdentifier: String?
    var useTLS: Bool = true
    var databaseType: DatabaseType = .postgresql
    var serverVersion: String?

    static let example = SavedConnection(
        connectionName: "Local",
        host: "localhost",
        port: 5432,
        database: "postgres",
        username: "postgres",
        keychainIdentifier: nil,
        useTLS: false,
        databaseType: .postgresql
    )
}
