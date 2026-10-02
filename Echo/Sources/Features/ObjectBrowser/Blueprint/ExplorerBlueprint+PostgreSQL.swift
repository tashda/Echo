import Foundation

extension ExplorerBlueprint {
    /// PostgreSQL, in pgAdmin's order, with the server tools Echo has as sections (round 16):
    /// Activity Monitor's pages, the server-wide maintenance and backup tools, and tablespaces.
    nonisolated static let postgreSQL = ExplorerBlueprint {
        Databases()
        Folder(.serverSecurity, loading: .serverSecurity) {
            ItemFolder(.loginRoles)
            ItemFolder(.groupRoles)
        }
        Folder(.activity) {
            Tool(.pgSessions)
            Tool(.pgLocks)
            Tool(.pgDatabaseStatistics)
            Tool(.pgOperations)
            Tool(.pgQueries)
            Tool(.pgReplication)
            Tool(.pgIOStatistics)
            Tool(.pgWAL)
            Tool(.pgBackgroundWriter)
            Tool(.pgPreparedTransactions)
            Tool(.pgConfiguration)
        }
        Folder(.management) {
            Tool(.maintenance)
            Tool(.backUpServer)
            Tool(.backUpGlobals)
            Tool(.psqlConsole)
            Tool(.pgTypes)
            Tool(.pgTextAndLanguages)
            Tool(.pgProgramming)
            Tool(.pgStorage)
        }
        ItemFolder(.tablespaces, loading: .tablespaces)
    } database: {
        ObjectFolders(.tables, .views, .materializedViews, .functions, .procedures, .triggers, .sequences, .types, .extensions)
    }
}
