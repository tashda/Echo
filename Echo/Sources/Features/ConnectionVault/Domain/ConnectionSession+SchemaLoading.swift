import Foundation

// MARK: - Schema Loading

extension ConnectionSession {

    func cancelStructureLoadTask() async {
        let task = structureLoadTask
        structureLoadTask = nil
        task?.cancel()
        if let task {
            await task.value
        }
    }

    func hasLoadedSchema(forDatabase databaseName: String) -> Bool {
        let normalizedName = normalizedDatabaseName(databaseName)
        guard !normalizedName.isEmpty else { return false }
        let key = schemaLoadKey(normalizedName)
        if metadataFreshnessByDatabase[key] == .listOnly {
            return false
        }
        return databaseStructure?.databases
            .first(where: { normalizedDatabaseName($0.name).caseInsensitiveCompare(normalizedName) == .orderedSame }) != nil
    }

    func beginSchemaLoad(forDatabase databaseName: String) -> Bool {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return false }
        if schemaLoadsInFlight.contains(loadKey) {
            return false
        }
        schemaLoadsInFlight.insert(loadKey)
        return true
    }

    func finishSchemaLoad(forDatabase databaseName: String) {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return }
        schemaLoadsInFlight.remove(loadKey)
    }

    var activeDatabaseName: String? {
        let tabDatabase = activeQueryTab?.activeDatabaseName.map(normalizedDatabaseName)
        if let tabDatabase, !tabDatabase.isEmpty {
            return tabDatabase
        }

        let selectedDatabase = sidebarFocusedDatabase.map(normalizedDatabaseName)
        if let selectedDatabase, !selectedDatabase.isEmpty {
            return selectedDatabase
        }

        let connectionDatabase = normalizedDatabaseName(connection.database)
        return connectionDatabase.isEmpty ? nil : connectionDatabase
    }

    func normalizedDatabaseName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func schemaLoadKey(_ value: String) -> String {
        normalizedDatabaseName(value).lowercased()
    }
}
