import Foundation

extension ExplorerBlueprint {
    /// PostgreSQL, in pgAdmin's order.
    nonisolated static let postgreSQL = ExplorerBlueprint {
        Databases()
        Folder(.serverSecurity, loading: .serverSecurity) {
            ItemFolder(.loginRoles)
            ItemFolder(.groupRoles)
        }
    } database: {
        ObjectFolders(.tables, .views, .materializedViews, .functions, .procedures, .triggers, .sequences, .types, .extensions)
    }
}
