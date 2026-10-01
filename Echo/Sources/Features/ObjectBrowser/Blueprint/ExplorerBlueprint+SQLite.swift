import Foundation

extension ExplorerBlueprint {
    /// SQLite: attached databases and their tables and views.
    nonisolated static let sqlite = ExplorerBlueprint {
        Databases()
        Folder(.management) {
            Tool(.maintenance)
        }
    } database: {
        ObjectFolders(.tables, .views)
    }
}
