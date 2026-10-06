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
        // The list slice, not the structure: this is asked while the tree is built, which must not
        // depend on every schema that loads in the background.
        return databaseSummaries
            .first(where: { normalizedDatabaseName($0.name).caseInsensitiveCompare(normalizedName) == .orderedSame }) != nil
    }

    /// One database with its schemas. A view that reads it is told when this database changed,
    /// and not when another database's schemas arrive.
    func databaseInfo(named name: String) -> DatabaseInfo? {
        if let slot = databaseSlots[name] { return slot.info }
        let slot = DatabaseSlot(info: structureSnapshot?.databases.first(where: { $0.name == name }))
        databaseSlots[name] = slot
        return slot.info
    }

    func beginSchemaLoad(forDatabase databaseName: String) -> Bool {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return false }
        if schemaLoadsInFlight.contains(loadKey) {
            return false
        }
        schemaLoadsInFlight.insert(loadKey)
        schemaLoadFlag(forDatabase: loadKey).isLoading = true
        return true
    }

    func finishSchemaLoad(forDatabase databaseName: String) {
        let loadKey = schemaLoadKey(databaseName)
        guard !loadKey.isEmpty else { return }
        schemaLoadsInFlight.remove(loadKey)
        schemaLoadFlag(forDatabase: loadKey).isLoading = false
    }

    /// Whether the database's schema is loading, as an object of its own: a row reads it and is told
    /// when that one database starts or stops, not for every other database's load.
    func schemaLoadFlag(forDatabase databaseName: String) -> SchemaLoadFlag {
        let key = schemaLoadKey(databaseName)
        if let flag = schemaLoadFlags[key] { return flag }
        let flag = SchemaLoadFlag(isLoading: schemaLoadsInFlight.contains(key))
        schemaLoadFlags[key] = flag
        return flag
    }

    func clearSchemaLoadFlags() {
        for flag in schemaLoadFlags.values where flag.isLoading { flag.isLoading = false }
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
