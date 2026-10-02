import EchoLocalStorage
import Foundation

extension SyncEngine {
    func applyRemoteChanges(_ documents: [SyncDocument], project: Project, checkpoint: UInt64) async throws {
        guard let connectionStore, let projectStore, let accountID else { throw LocalStorageError.concurrentChange }
        let epoch = accountEpoch
        let storage = EncryptedRecordStore.shared
        let generation = try await storage.generation()
        let originalConnections = connectionStore.connections
        let originalFolders = connectionStore.folders
        let originalIdentities = connectionStore.identities
        let originalProjects = projectStore.projects
        var connections = originalConnections
        var folders = originalFolders
        var identities = originalIdentities
        var projects = originalProjects

        for doc in documents {
            switch doc.collection {
            case .connections:
                if doc.isDeleted { connections.removeAll { $0.id == doc.id } }
                else {
                    var value = try adapter.applyToConnection(doc, existing: connections.first { $0.id == doc.id })
                    applyEncryptedCredentials(from: doc, projectID: project.id, keychainID: &value.keychainIdentifier, displayName: value.connectionName)
                    Self.upsert(value, into: &connections)
                }
            case .folders:
                if doc.isDeleted { folders.removeAll { $0.id == doc.id } }
                else { Self.upsert(try adapter.applyToFolder(doc, existing: folders.first { $0.id == doc.id }), into: &folders) }
            case .identities:
                if doc.isDeleted { identities.removeAll { $0.id == doc.id } }
                else {
                    var value = try adapter.applyToIdentity(doc, existing: identities.first { $0.id == doc.id })
                    applyEncryptedCredentials(from: doc, projectID: project.id, keychainID: &value.keychainIdentifier, displayName: value.name)
                    Self.upsert(value, into: &identities)
                }
            case .projects:
                if !doc.isDeleted {
                    Self.upsert(try adapter.applyToProject(doc, existing: projects.first { $0.id == doc.id }), into: &projects)
                }
            case .bookmarks:
                if let index = projects.firstIndex(where: { $0.id == project.id }) {
                    if doc.isDeleted { projects[index].bookmarks.removeAll { $0.id == doc.id } }
                    else {
                        let bookmark = try adapter.applyToBookmark(doc, existing: projects[index].bookmarks.first { $0.id == doc.id })
                        Self.upsert(bookmark, into: &projects[index].bookmarks)
                    }
                }
            case .settings:
                if !doc.isDeleted, let index = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[index].projectGlobalSettings = try adapter.applyToSettings(doc, existing: projects[index].projectGlobalSettings)
                }
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let connectionRecords = try connections.enumerated().map { position, value in
            var lean = value
            lean.cachedStructure = nil
            lean.cachedStructureUpdatedAt = nil
            return LocalRecord(collection: "connections", id: value.id.uuidString, group: value.projectID?.uuidString,
                payload: try encoder.encode(lean), position: position)
        }
        let folderRecords = try folders.enumerated().map { position, value in
            LocalRecord(collection: "folders", id: value.id.uuidString, group: value.projectID?.uuidString,
                payload: try encoder.encode(value), position: position)
        }
        let identityRecords = try identities.enumerated().map { position, value in
            LocalRecord(collection: "identities", id: value.id.uuidString, group: value.projectID?.uuidString,
                payload: try encoder.encode(value), position: position)
        }
        let snapshots = try ProjectDiskStore.snapshots(projects) + [
            LocalCollectionSnapshot(collection: "connections", records: connectionRecords),
            LocalCollectionSnapshot(collection: "folders", records: folderRecords),
            LocalCollectionSnapshot(collection: "identities", records: identityRecords)]
        let checkpointRecord = try await checkpointStore.record(projectID: project.id, checkpoint: checkpoint)
        guard epoch == accountEpoch, status != .disabled else { throw CancellationError() }
        try await storage.replaceCollections(snapshots, remote: true, expectedGeneration: generation,
            checkpoint: checkpointRecord, expectedAccount: accountID, project: project.id.uuidString,
            requireNoPending: Set(SyncPreferences.enabledCollections().map(\.rawValue)))
        guard epoch == accountEpoch, status != .disabled else { throw CancellationError() }

        // Preserve UI edits made while the database actor was committing the remote batch.
        connectionStore.connections = try Self.publish(original: originalConnections, remote: connections, current: connectionStore.connections)
        connectionStore.folders = try Self.publish(original: originalFolders, remote: folders, current: connectionStore.folders)
        connectionStore.identities = try Self.publish(original: originalIdentities, remote: identities, current: connectionStore.identities)
        projectStore.projects = try Self.publish(original: originalProjects, remote: projects, current: projectStore.projects)
        if let selected = projectStore.selectedProject,
           let updated = projectStore.projects.first(where: { $0.id == selected.id }) {
            projectStore.selectedProject = updated
            if let settings = updated.projectGlobalSettings { projectStore.globalSettings = settings }
        }
    }

    private static func upsert<Value: Identifiable>(_ value: Value, into values: inout [Value]) {
        if let index = values.firstIndex(where: { $0.id == value.id }) { values[index] = value }
        else { values.append(value) }
    }

    private static func publish<Value: Codable & Identifiable>(original: [Value], remote: [Value], current: [Value]) throws -> [Value] where Value.ID == UUID {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let originalData = try Dictionary(uniqueKeysWithValues: original.map { ($0.id, try encoder.encode($0)) })
        let currentData = try Dictionary(uniqueKeysWithValues: current.map { ($0.id, try encoder.encode($0)) })
        var result = current
        for value in remote where currentData[value.id] == originalData[value.id] {
            Self.upsert(value, into: &result)
        }
        let remoteIDs = Set(remote.map(\.id))
        result.removeAll { originalData[$0.id] != nil && !remoteIDs.contains($0.id) && currentData[$0.id] == originalData[$0.id] }
        return result
    }
}
