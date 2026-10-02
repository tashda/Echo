import Foundation
import OSLog
import EchoLocalStorage

extension SyncEngine {
    // MARK: - E2E Credential Encryption (Push)

    /// Add encrypted password field to a sync document if E2E is active.
    func addEncryptedCredentials(to doc: inout SyncDocument, keychainID: String?, projectID: UUID, hlc: UInt64) throws {
        guard SyncPreferences.isCredentialSyncEnabled,
              let keyStore = e2eKeyStore, keyStore.isUnlocked,
              let projectKey = keyStore.projectKey(for: projectID),
              let keychainID, !keychainID.isEmpty else { return }

        let vault = KeychainVault()
        guard let password = try? vault.getPassword(account: keychainID), !password.isEmpty else { return }

        doc.fields["encryptedPassword"] = try fieldEncryptor.encryptField(
            plaintext: password,
            key: projectKey,
            collection: doc.collection,
            documentID: doc.id,
            fieldName: "encryptedPassword",
            hlc: hlc
        )
    }

    // MARK: - E2E Credential Decryption (Pull)

    /// Decrypt and store credentials from a pulled sync document.
    /// If the local Keychain already has a different password, a conflict is recorded
    /// instead of silently overwriting.
    func applyEncryptedCredentials(from doc: SyncDocument, projectID: UUID, keychainID: inout String?, displayName: String = "") {
        guard SyncPreferences.isCredentialSyncEnabled,
              let keyStore = e2eKeyStore, keyStore.isUnlocked,
              let projectKey = keyStore.projectKey(for: projectID),
              let encField = doc.fields["encryptedPassword"], encField.isEncrypted else { return }

        do {
            let cloudPassword = try fieldEncryptor.decryptField(
                field: encField,
                key: projectKey,
                collection: doc.collection,
                documentID: doc.id,
                fieldName: "encryptedPassword"
            )

            // Generate a keychain identifier if one doesn't exist
            if keychainID == nil || keychainID!.isEmpty {
                let prefix = doc.collection == .identities ? "echo.identity" : "echo"
                keychainID = "\(prefix).\(doc.id.uuidString)"
            }

            let vault = KeychainVault()

            // Check for conflict: local Keychain has a different password
            if let localPassword = try? vault.getPassword(account: keychainID!),
               !localPassword.isEmpty,
               localPassword != cloudPassword {
                // Record the conflict for user resolution
                let name = displayName.isEmpty ? doc.id.uuidString : displayName
                pendingCredentialConflicts.append(CredentialConflict(
                    id: doc.id,
                    collection: doc.collection,
                    displayName: name,
                    localPassword: localPassword,
                    cloudPassword: cloudPassword
                ))
                logger.info("Credential conflict detected for \(doc.id) — deferring to user")
                return
            }

            // No conflict — apply cloud password
            try vault.setPassword(cloudPassword, account: keychainID!)
        } catch {
            logger.error("Failed to decrypt credential for \(doc.id): \(error.localizedDescription)")
        }
    }

    // MARK: - Initial Upload

    /// Check whether the server already has data for this project and build a summary.
    /// The caller uses this to decide whether to show a merge strategy prompt.
    func checkSyncDataSummary(for project: Project) async throws -> SyncDataSummary {
        guard let connectionStore else {
            return SyncDataSummary(localConnections: 0, localIdentities: 0, localFolders: 0, localBookmarks: 0, cloudDocuments: 0)
        }

        let userID = try await syncClient.currentUserID()
        let serverID = syncClient.serverProjectID(localID: project.id, userID: userID)
        let cloudCount = try await syncClient.cloudDocumentCount(projectID: serverID)

        return SyncDataSummary(
            localConnections: connectionStore.connections.filter { $0.projectID == project.id }.count,
            localIdentities: connectionStore.identities.filter { $0.projectID == project.id }.count,
            localFolders: connectionStore.folders.filter { $0.projectID == project.id }.count,
            localBookmarks: project.bookmarks.count,
            cloudDocuments: cloudCount
        )
    }

    /// Upload all local data for a project to the server for the first time.
    /// Called when a user enables sync on an existing project.
    ///
    /// - Parameter strategy: How to handle existing data on both sides.
    ///   - `.uploadLocal`: Push local data to cloud (original behavior).
    ///   - `.useCloud`: Pull cloud data and replace local state. Local-only items are deleted.
    ///   - `.merge`: Push local, then pull cloud — LWW resolves conflicts.
    func performInitialUpload(for project: Project, strategy: SyncMergeStrategy = .merge) async throws {
        guard let projectStore else { return }

        // Register project on server first (using per-user server ID)
        let userID = try await syncClient.currentUserID()
        let serverID = syncClient.serverProjectID(localID: project.id, userID: userID)
        let sortOrder = projectStore.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        try await syncClient.upsertProject(serverID: serverID, userID: userID, name: project.name, sortOrder: sortOrder)

        switch strategy {
        case .uploadLocal:
            try await uploadLocalData(for: project)
            try await pullChanges(for: project, serverProjectID: serverID)
            logger.info("Initial upload (uploadLocal) complete for '\(project.name)'")

        case .useCloud:
            // Delete local data for this project, then pull everything from cloud
            try await deleteLocalProjectData(for: project)
            try await pullChanges(for: project, serverProjectID: serverID)
            logger.info("Initial sync (useCloud) complete for '\(project.name)'")

        case .merge:
            // Upload local first, then pull cloud — LWW resolves conflicts at field level
            try await uploadLocalData(for: project)
            try await pullChanges(for: project, serverProjectID: serverID)
            logger.info("Initial sync (merge) complete for '\(project.name)'")
        }
    }

    /// Push all local data for a project to the server.
    func uploadLocalData(for project: Project) async throws {
        guard let connectionStore else { return }

        var documents: [SyncDocument] = []
        let hlc = clock.now()
        let userID = try await syncClient.currentUserID()
        let serverProjectID = syncClient.serverProjectID(localID: project.id, userID: userID)

        // Project itself
        documents.append(try adapter.toSyncDocument(project, hlc: hlc))

        // Connections belonging to this project
        let projectConnections = connectionStore.connections.filter { $0.projectID == project.id }
        for conn in projectConnections {
            var doc = try adapter.toSyncDocument(conn, hlc: hlc)
            try addEncryptedCredentials(to: &doc, keychainID: conn.keychainIdentifier, projectID: project.id, hlc: hlc)
            documents.append(doc)
        }

        // Folders belonging to this project
        let projectFolders = connectionStore.folders.filter { $0.projectID == project.id }
        for folder in projectFolders {
            documents.append(try adapter.toSyncDocument(folder, hlc: hlc))
        }

        // Identities belonging to this project
        let projectIdentities = connectionStore.identities.filter { $0.projectID == project.id }
        for identity in projectIdentities {
            var doc = try adapter.toSyncDocument(identity, hlc: hlc)
            try addEncryptedCredentials(to: &doc, keychainID: identity.keychainIdentifier, projectID: project.id, hlc: hlc)
            documents.append(doc)
        }

        // Bookmarks
        for bookmark in project.bookmarks {
            documents.append(try adapter.toSyncDocument(bookmark, projectID: project.id, hlc: hlc))
        }

        // Settings
        if let settings = project.projectGlobalSettings {
            documents.append(try adapter.toSyncDocument(settings: settings, projectID: project.id, hlc: hlc))
        }

        guard !documents.isEmpty else { return }

        // Push in batches of 100
        let batchSize = 100
        for batchStart in stride(from: 0, to: documents.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, documents.count)
            let batch = Array(documents[batchStart..<batchEnd])
            let response = try await syncClient.push(changes: batch, projectID: serverProjectID)
            logger.info("Initial upload batch: \(response.accepted) accepted")
        }

        logger.info("Uploaded \(documents.count) documents for project '\(project.name)'")
    }

    /// Delete all local data for a project (connections, folders, identities, bookmarks).
    /// Used by the "Use Cloud" strategy to start fresh from server state.
    func deleteLocalProjectData(for project: Project) async throws {
        guard let connectionStore, let projectStore else { return }

        // Delete connections
        let projectConnections = connectionStore.connections.filter { $0.projectID == project.id }
        for conn in projectConnections {
            try await connectionStore.deleteConnection(conn)
        }

        // Delete folders
        let projectFolders = connectionStore.folders.filter { $0.projectID == project.id }
        for folder in projectFolders {
            try await connectionStore.deleteFolder(folder, reparentContents: false)
        }

        // Delete identities
        let projectIdentities = connectionStore.identities.filter { $0.projectID == project.id }
        for identity in projectIdentities {
            try await connectionStore.deleteIdentity(identity)
        }

        // Clear bookmarks
        if let idx = projectStore.projects.firstIndex(where: { $0.id == project.id }) {
            projectStore.projects[idx].bookmarks.removeAll()
            try await projectStore.updateProject(projectStore.projects[idx])
        }

        logger.info("Cleared local data for project '\(project.name)' before cloud pull")
    }

    // MARK: - Credential Conflict Detection

    /// Pending credential conflicts from the last pull cycle.
    /// The UI observes this to present a resolution prompt.


    /// Clear resolved conflicts.
    func clearCredentialConflicts() {
        pendingCredentialConflicts.removeAll()
    }

    /// Resolve a single credential conflict by choosing local or cloud.
    func resolveCredentialConflict(_ conflict: CredentialConflict, useCloud: Bool) {
        if useCloud {
            // Store cloud password in Keychain
            let vault = KeychainVault()
            let keychainID = conflict.collection == .identities
                ? "echo.identity.\(conflict.id.uuidString)"
                : "echo.\(conflict.id.uuidString)"
            try? vault.setPassword(conflict.cloudPassword, account: keychainID)
        }
        // If keeping local, nothing to do — local Keychain already has the password
        pendingCredentialConflicts.removeAll { $0.id == conflict.id }
    }

    /// Resolve all credential conflicts at once with the same choice.
    func resolveAllCredentialConflicts(useCloud: Bool) {
        for conflict in pendingCredentialConflicts {
            resolveCredentialConflict(conflict, useCloud: useCloud)
        }
    }
}
