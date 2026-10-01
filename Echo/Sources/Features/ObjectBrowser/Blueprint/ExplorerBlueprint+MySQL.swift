import Foundation

extension ExplorerBlueprint {
    /// MySQL. Server tools sit under Management so they don't read as more databases.
    nonisolated static let mySQL = ExplorerBlueprint {
        Databases()
        Folder(.management) {
            Tool(.maintenance)
            Tool(.serverProperties)
            Tool(.activityMonitor)
        }
    } database: {
        ObjectFolders(.tables, .views, .functions, .procedures, .triggers)
    }
}
