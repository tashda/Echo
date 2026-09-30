import Foundation

extension EnvironmentState {
    /// Remembers a table the user just opened, for the empty query tab's recent tables (QE6).
    /// Views and other objects are not tables and are left out.
    func recordRecentTable(_ object: SchemaObjectInfo, in session: ConnectionSession, databaseName: String?) {
        guard object.type == .table else { return }
        recentTables.record(
            connectionID: session.connection.id,
            databaseName: databaseName ?? session.sidebarFocusedDatabase ?? session.connection.database,
            schema: object.schema,
            name: object.name
        )
    }
}
