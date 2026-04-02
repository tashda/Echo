import Foundation

enum QueryEditorConnectionContextResolver {
    static func normalize(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func resolveDatabaseName(
        tabDatabaseName: String?,
        sessionDatabaseName: String?,
        connectionDatabaseName: String?
    ) -> String? {
        normalize(tabDatabaseName)
            ?? normalize(sessionDatabaseName)
            ?? normalize(connectionDatabaseName)
    }

    /// Returns the full structure with all databases so that cross-database detection
    /// can match any database name. EchoSense builds catalogs only for databases that
    /// have loaded schemas; empty databases are still present for name matching.
    static func completionStructure(
        from structure: DatabaseStructure?,
        selectedDatabase: String?
    ) -> DatabaseStructure? {
        structure
    }
}
