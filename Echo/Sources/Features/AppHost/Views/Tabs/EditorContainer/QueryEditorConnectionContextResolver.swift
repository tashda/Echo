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

    static func completionStructure(
        from structure: DatabaseStructure?,
        selectedDatabase: String?
    ) -> DatabaseStructure? {
        guard let structure else { return nil }
        guard let selectedDatabase = normalize(selectedDatabase) else { return structure }

        guard let matchingDatabase = structure.databases.first(where: {
            $0.name.caseInsensitiveCompare(selectedDatabase) == .orderedSame
        }) else {
            return structure
        }

        return DatabaseStructure(
            serverVersion: structure.serverVersion,
            databases: [matchingDatabase]
        )
    }
}
