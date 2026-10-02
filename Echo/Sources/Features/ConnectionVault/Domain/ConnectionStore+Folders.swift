import Foundation
import OSLog

private let folderLogger = Logger(subsystem: "dev.echodb.echo", category: "folders")

/// Folders organise connections and identities inside a project (nesting via
/// `parentFolderID`). They carry no credentials.
extension ConnectionStore {

    // MARK: - Queries

    /// The folder with this id, if any.
    func folder(id: UUID?) -> SavedFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    /// Folders of one kind in a project directly under `parentID` (nil = top level), sorted by name.
    /// A folder whose parent no longer exists counts as top level.
    func folders(kind: FolderKind, projectID: UUID?, parentID: UUID?) -> [SavedFolder] {
        folders
            .filter { $0.kind == kind && $0.projectID == projectID && effectiveParentID(of: $0) == parentID }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The folder a connection is shown in: its `folderID` when that is an existing
    /// connections folder of the same project, otherwise nil (top level). Older data can
    /// hold connections whose folder was deleted; they show at the top level.
    func effectiveFolderID(of connection: SavedConnection) -> UUID? {
        guard let folder = self.folder(id: connection.folderID),
              folder.kind == .connections,
              folder.projectID == connection.projectID else { return nil }
        return folder.id
    }

    /// The folder an identity is shown in (see `effectiveFolderID(of:)` for connections).
    func effectiveFolderID(of identity: SavedIdentity) -> UUID? {
        guard let folder = self.folder(id: identity.folderID),
              folder.kind == .identities,
              folder.projectID == identity.projectID else { return nil }
        return folder.id
    }

    /// The parent a folder is shown under: its `parentFolderID` when that folder exists,
    /// is of the same kind and project, and is not the folder itself; otherwise nil.
    func effectiveParentID(of folder: SavedFolder) -> UUID? {
        guard let parent = self.folder(id: folder.parentFolderID),
              parent.id != folder.id,
              parent.kind == folder.kind,
              parent.projectID == folder.projectID else { return nil }
        return parent.id
    }

    /// The chain of folders from the top level down to `folderID` (empty when nil or unknown).
    func folderPath(to folderID: UUID?) -> [SavedFolder] {
        var path: [SavedFolder] = []
        var visited: Set<UUID> = []
        var current = folderID
        while let id = current, !visited.contains(id), let folder = self.folder(id: id) {
            visited.insert(id)
            path.insert(folder, at: 0)
            current = folder.parentFolderID
        }
        return path
    }

    /// The ids of every folder nested (at any depth) inside `folderID`, not including it.
    func descendantFolderIDs(of folderID: UUID) -> Set<UUID> {
        var result: Set<UUID> = []
        var queue = [folderID]
        while let id = queue.popLast() {
            for child in folders where child.parentFolderID == id && !result.contains(child.id) && child.id != folderID {
                result.insert(child.id)
                queue.append(child.id)
            }
        }
        return result
    }

    // MARK: - CRUD

    /// Creates a folder, saves it and returns it.
    @discardableResult
    func createFolder(
        name: String,
        kind: FolderKind = .connections,
        projectID: UUID?,
        parentFolderID: UUID? = nil
    ) async throws -> SavedFolder {
        let folder = SavedFolder(
            name: name,
            projectID: projectID,
            parentFolderID: parentFolderID,
            kind: kind
        )
        try await updateFolder(folder)
        return folder
    }

    /// Inserts or replaces a folder and saves.
    func updateFolder(_ folder: SavedFolder) async throws {
        if let index = folders.firstIndex(where: { $0.id == folder.id }) {
            folders[index] = folder
        } else {
            folders.append(folder)
        }
        try await saveFolders()
        if let projectID = folder.projectID {
            onDataChanged?(folder.id, .folders, projectID, false)
        }
    }

    /// Renames a folder. Does nothing when the folder is unknown or the trimmed name is empty.
    func renameFolder(_ folderID: UUID, to name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var folder = self.folder(id: folderID) else { return }
        folder.name = trimmed
        try await updateFolder(folder)
    }

    /// Deletes a folder. With `reparentContents` (the default) its connections, identities
    /// and child folders move up to the folder's parent (or the top level), so nothing is lost.
    /// Sync passes `false`: the deleting device already moved the contents.
    func deleteFolder(_ folder: SavedFolder, reparentContents: Bool = true) async throws {
        let projectID = folder.projectID
        let newParent = folder.parentFolderID

        var movedConnections: [SavedConnection] = []
        var movedIdentities: [SavedIdentity] = []
        var movedFolders: [SavedFolder] = []

        if reparentContents {
            for index in connections.indices where connections[index].folderID == folder.id {
                connections[index].folderID = newParent
                movedConnections.append(connections[index])
            }
            for index in identities.indices where identities[index].folderID == folder.id {
                identities[index].folderID = newParent
                movedIdentities.append(identities[index])
            }
            for index in folders.indices where folders[index].parentFolderID == folder.id {
                folders[index].parentFolderID = newParent
                movedFolders.append(folders[index])
            }
        }

        folders.removeAll { $0.id == folder.id }

        if !movedConnections.isEmpty { try await saveConnections() }
        if !movedIdentities.isEmpty { try await saveIdentities() }
        try await saveFolders()

        for connection in movedConnections {
            if let projectID = connection.projectID { onDataChanged?(connection.id, .connections, projectID, false) }
        }
        for identity in movedIdentities {
            if let projectID = identity.projectID { onDataChanged?(identity.id, .identities, projectID, false) }
        }
        for child in movedFolders {
            if let projectID = child.projectID { onDataChanged?(child.id, .folders, projectID, false) }
        }
        if let projectID {
            onDataChanged?(folder.id, .folders, projectID, true)
        }
    }

    // MARK: - Moving

    /// Files these connections in `folderID` (nil = top level). Unknown ids are skipped;
    /// a folder id that does not exist moves them to the top level.
    func moveConnections(_ ids: Set<UUID>, toFolder folderID: UUID?) async {
        let target = folder(id: folderID)?.id
        var moved: [SavedConnection] = []
        for index in connections.indices where ids.contains(connections[index].id) && connections[index].folderID != target {
            connections[index].folderID = target
            moved.append(connections[index])
        }
        guard !moved.isEmpty else { return }
        do {
            try await saveConnections()
        } catch {
            folderLogger.error("Saving connections after a move failed: \(error.localizedDescription, privacy: .public)")
        }
        for connection in moved {
            if let projectID = connection.projectID { onDataChanged?(connection.id, .connections, projectID, false) }
        }
    }

    /// Files these identities in `folderID` (nil = top level). Unknown ids are skipped;
    /// a folder id that does not exist moves them to the top level.
    func moveIdentities(_ ids: Set<UUID>, toFolder folderID: UUID?) async {
        let target = folder(id: folderID)?.id
        var moved: [SavedIdentity] = []
        for index in identities.indices where ids.contains(identities[index].id) && identities[index].folderID != target {
            identities[index].folderID = target
            moved.append(identities[index])
        }
        guard !moved.isEmpty else { return }
        do {
            try await saveIdentities()
        } catch {
            folderLogger.error("Saving identities after a move failed: \(error.localizedDescription, privacy: .public)")
        }
        for identity in moved {
            if let projectID = identity.projectID { onDataChanged?(identity.id, .identities, projectID, false) }
        }
    }

    /// Nests a folder under `parentID` (nil = top level). Refused (returns false) when the
    /// parent is the folder itself or one of its descendants, or when either folder is unknown.
    @discardableResult
    func moveFolder(_ folderID: UUID, toParent parentID: UUID?) async -> Bool {
        guard var moving = folder(id: folderID) else { return false }
        if let parentID {
            guard parentID != folderID,
                  folder(id: parentID) != nil,
                  !descendantFolderIDs(of: folderID).contains(parentID) else { return false }
        }
        guard moving.parentFolderID != parentID else { return true }
        moving.parentFolderID = parentID
        do {
            try await updateFolder(moving)
        } catch {
            folderLogger.error("Saving folders after a move failed: \(error.localizedDescription, privacy: .public)")
        }
        return true
    }
}
