import SwiftUI

/// Creates an independent observation boundary for database content.
/// Reads the live database directly from session.databaseStructure so it re-renders
/// immediately when the structure changes — without waiting for the parent ForEach to re-diff.
struct DatabaseContentView<Content: View>: View {
    let databaseName: String
    let session: ConnectionSession
    @ViewBuilder let content: (DatabaseInfo, Bool) -> Content

    /// Direct observation on session.databaseStructure — this is the key.
    /// When mergeSingleDatabase updates the structure, this view re-evaluates immediately.
    private var liveDatabase: DatabaseInfo? {
        session.databaseStructure?.databases.first(where: { $0.name == databaseName })
    }

    private var hasSchemas: Bool {
        guard let db = liveDatabase else { return false }
        return !db.schemas.isEmpty && db.schemas.contains(where: { !$0.objects.isEmpty })
    }

    var body: some View {
        let database = liveDatabase ?? DatabaseInfo(name: databaseName, schemas: [], schemaCount: 0)
        content(database, hasSchemas)
    }
}
