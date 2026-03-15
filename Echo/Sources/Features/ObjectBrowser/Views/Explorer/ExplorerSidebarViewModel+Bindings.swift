import SwiftUI
import EchoSense

extension ObjectBrowserSidebarViewModel {

    // MARK: - Per-Session Bindings

    func expandedObjectGroupsBinding(for connectionID: UUID, database: String) -> Binding<Set<SchemaObjectInfo.ObjectType>> {
        let key = "\(connectionID.uuidString)#\(database)"
        return Binding(
            get: { [weak self] in
                guard let self else { return Set(SchemaObjectInfo.ObjectType.allCases) }
                return self.expandedObjectGroupsBySession[key] ?? self.defaultExpandedObjectTypes[connectionID] ?? Set(SchemaObjectInfo.ObjectType.allCases)
            },
            set: { [weak self] in self?.expandedObjectGroupsBySession[key] = $0 }
        )
    }

    func defaultExpandedObjectGroups(for connectionID: UUID) -> Set<SchemaObjectInfo.ObjectType> {
        defaultExpandedObjectTypes[connectionID] ?? []
    }

    func expandedObjectIDsBinding(for connectionID: UUID, database: String) -> Binding<Set<String>> {
        let key = "\(connectionID.uuidString)#\(database)"
        return Binding(
            get: { [weak self] in self?.expandedObjectIDsBySession[key] ?? [] },
            set: { [weak self] in self?.expandedObjectIDsBySession[key] = $0 }
        )
    }

    func selectedSchemaNameBinding(for connectionID: UUID, database: String) -> Binding<String?> {
        let key = "\(connectionID.uuidString)#\(database)"
        return Binding(
            get: { [weak self] in self?.selectedSchemaNameBySession[key] },
            set: { [weak self] newValue in
                if let newValue {
                    self?.selectedSchemaNameBySession[key] = newValue
                } else {
                    self?.selectedSchemaNameBySession.removeValue(forKey: key)
                }
            }
        )
    }

    func ensureServerExpanded(for connectionID: UUID, sessions: [ConnectionSession]) {
        expandedServerIDs = expandedServerIDs.filter { id in
            sessions.contains { $0.connection.id == id }
        }
        expandedServerIDs.insert(connectionID)
    }

    func ensureDatabaseExpanded(connectionID: UUID, databaseName: String) {
        var expanded = expandedDatabasesBySession[connectionID] ?? []
        expanded.insert(databaseName)
        expandedDatabasesBySession[connectionID] = expanded
    }

    func pinnedStorageKey(connectionID: UUID, databaseName: String) -> String {
        "\(connectionID.uuidString)#\(databaseName)"
    }

    func pinnedObjectsBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Set<String>> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { [weak self] in self?.pinnedObjectIDsByDatabase[key] ?? [] },
            set: { [weak self] newValue in
                if newValue.isEmpty {
                    self?.pinnedObjectIDsByDatabase.removeValue(forKey: key)
                } else {
                    self?.pinnedObjectIDsByDatabase[key] = newValue
                }
            }
        )
    }

    func pinnedSectionExpandedBinding(for database: DatabaseInfo, connectionID: UUID) -> Binding<Bool> {
        let key = pinnedStorageKey(connectionID: connectionID, databaseName: database.name)
        return Binding(
            get: { [weak self] in self?.pinnedSectionExpandedByDatabase[key] ?? true },
            set: { [weak self] newValue in
                self?.pinnedSectionExpandedByDatabase[key] = newValue
            }
        )
    }
}
