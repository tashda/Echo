import Foundation

extension QueryEditorContainer {
    /// QE6: the tables last opened on this tab's connection and database, each with the query
    /// for its first rows.
    func emptyTabTableStarts() -> [EmptyQueryHints.TableStart] {
        let session = connectionSession
        let connection = session?.connection ?? tab.connection
        let database = QueryEditorConnectionContextResolver.resolveDatabaseName(
            tabDatabaseName: tab.activeDatabaseName,
            sessionDatabaseName: session?.sidebarFocusedDatabase,
            connectionDatabaseName: connection.database
        )
        return environmentState.recentTables
            .recent(forConnection: connection.id, database: database, limit: LayoutTokens.EmptyQueryHints.recentTableCount)
            .map { table in
                EmptyQueryHints.TableStart(
                    table: table,
                    sql: TablePreviewQuery.sql(schema: table.schema, table: table.name, databaseType: connection.databaseType)
                )
            }
    }
}
