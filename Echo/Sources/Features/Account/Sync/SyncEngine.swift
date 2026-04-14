import Foundation
import Observation
import os.log
import Supabase

/// Orchestrates cloud sync between local Echo stores and the Supabase backend.
///
/// The engine runs pull→merge→apply→push cycles, tracking checkpoints and dirty
/// state so that only changed data is transferred. It is offline-first: all
/// operations work locally, and sync happens opportunistically when the network
/// is available.
///
/// ## Lifecycle
/// - Created by `AppDirector` when `SupabaseConfig.isConfigured` is true.
/// - Started when the user signs in (`start()`).
/// - Stopped when the user signs out (`stop()`).
/// - Individual syncs triggered by `SyncScheduler` or manually via `syncNow()`.
@Observable @MainActor
final class SyncEngine {

    // MARK: - Observable State

    private(set) var status: SyncStatus = .disabled
    private(set) var lastSyncedAt: Date?

    // MARK: - Dependencies

    @ObservationIgnored private let syncClient: SyncClient
    @ObservationIgnored private let adapter: SyncAdapter
    @ObservationIgnored private let merger: SyncMerger
    @ObservationIgnored let checkpointStore: SyncCheckpointStore
    @ObservationIgnored private let dirtyTracker: SyncDirtyTracker
    @ObservationIgnored private let fieldEncryptor = E2EFieldEncryptor()

    /// E2E key store — provides project keys for credential encryption.
    @ObservationIgnored var e2eKeyStore: E2EKeyStore?
    @ObservationIgnored private var clock: HybridClock

    @ObservationIgnored private let logger = Logger(subsystem: "dev.echodb.echo", category: "sync")

    /// References to the app stores, set after initialization.
    @ObservationIgnored weak var connectionStore: ConnectionStore?
    @ObservationIgnored weak var projectStore: ProjectStore?

    /// Whether a sync cycle is currently running.
    @ObservationIgnored private var isSyncing = false

    // MARK: - Init

    init?(syncClient: SyncClient? = nil) {
        guard let client = syncClient ?? SyncClient() else { return nil }
        self.syncClient = client
        self.adapter = SyncAdapter()
        self.merger = SyncMerger()
        self.checkpointStore = SyncCheckpointStore()
        self.dirtyTracker = SyncDirtyTracker()
        self.clock = HybridClock()
    }

    // MARK: - Lifecycle

    func start() async {
        do {
            try await checkpointStore.load()
            try await dirtyTracker.load()
            status = .idle
            logger.info("Sync engine started")
        } catch {
            logger.error("Failed to start sync engine: \(error.localizedDescription)")
            status = .error("Failed to initialize sync state")
        }
    }

    func stop() async {
        status = .disabled
        logger.info("Sync engine stopped")
    }

    /// Checks if a different user signed in. If so, resets sync state.
    /// Same user signing back in keeps `isSyncEnabled` intact.
    func resetIfUserChanged(currentUserID: String?) async {
        guard let currentUserID else { return }

        let previousUserID = UserDefaults.standard.string(forKey: "sync.lastUserID")

        if let previousUserID, previousUserID != currentUserID {
            // Different user — reset sync on all projects
            logger.info("User changed (\(previousUserID) → \(currentUserID)), resetting sync state")

            if let projectStore {
                for i in projectStore.projects.indices where projectStore.projects[i].isSyncEnabled {
                    projectStore.projects[i].isSyncEnabled = false
                    try? await projectStore.updateProject(projectStore.projects[i])
                }
            }

            try? await checkpointStore.clearAll()
            try? await dirtyTracker.clearAll()
            lastSyncedAt = nil
        }

        UserDefaults.standard.set(currentUserID, forKey: "sync.lastUserID")
    }

    // MARK: - Sync Trigger

    /// Run a full sync cycle for all sync-enabled projects.
    func syncNow() async {
        guard !isSyncing else {
            logger.debug("Sync already in progress, skipping")
            return
        }
        switch status {
        case .idle, .error:
            break // Allow sync from idle or retry after error
        default:
            return
        }

        if await hasPendingMergeDecision() {
            logger.info("Sync is waiting for a merge decision before the initial sync can continue")
            status = .idle
            return
        }

        isSyncing = true
        status = .syncing

        defer {
            isSyncing = false
        }

        do {
            guard let projectStore else {
                logger.warning("ProjectStore not available, skipping sync")
                status = .idle
                return
            }

            let projects = projectStore.projects.filter { $0.isSyncEnabled }
            guard !projects.isEmpty else {
                logger.debug("No sync-enabled projects")
                status = .idle
                return
            }

            for project in projects {
                try await syncProject(project)
            }

            lastSyncedAt = Date()
            status = .idle
            logger.info("Sync completed successfully")
        } catch is CancellationError {
            logger.debug("Sync cancelled")
            status = .idle
        } catch Supabase.AuthError.sessionMissing {
            logger.info("Skipping sync because the auth session is not ready yet")
            status = .idle
        } catch {
            logger.error("Sync failed: \(error.localizedDescription)")
            status = .error(error.localizedDescription)
        }
    }

    // MARK: - Dirty Marking (called by stores)

    func markDirty(id: UUID, collection: SyncCollection, projectID: UUID) {
        Task {
            try? await dirtyTracker.markDirty(id: id, collection: collection, projectID: projectID)
        }
    }

    func markDeleted(id: UUID, collection: SyncCollection, projectID: UUID) {
        Task {
            try? await dirtyTracker.markDeleted(id: id, collection: collection, projectID: projectID)
        }
    }

    // MARK: - Project Sync

    private func syncProject(_ project: Project) async throws {
        let userID = try await syncClient.currentUserID()
        let serverID = syncClient.serverProjectID(localID: project.id, userID: userID)

        // 1. Ensure project exists on server (using per-user server ID)
        let sortOrder = projectStore?.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        try await syncClient.upsertProject(serverID: serverID, userID: userID, name: project.name, sortOrder: sortOrder)

        // 2. Pull remote changes (using server project ID)
        try await pullChanges(for: project, serverProjectID: serverID)

        // 3. Push local changes (using server project ID)
        try await pushChanges(for: project, serverProjectID: serverID)
    }

    // MARK: - Pull

    private func pullChanges(for project: Project, serverProjectID: UUID) async throws {
        let checkpoint = await checkpointStore.checkpoint(for: project.id)

        var hasMore = true
        var currentCheckpoint = checkpoint

        while hasMore {
            let response = try await syncClient.pull(
                checkpoint: currentCheckpoint,
                projectID: serverProjectID
            )

            // Update clock from remote HLCs
            for doc in response.documents {
                let maxRemoteHLC = doc.fields.values.map(\.hlc).max() ?? 0
                clock.receive(remote: maxRemoteHLC)
            }

            // Apply remote changes to local stores (filtered by user preferences)
            let enabled = SyncPreferences.enabledCollections()
            let filtered = response.documents.filter { enabled.contains($0.collection) }
            try await applyRemoteChanges(filtered, project: project)

            currentCheckpoint = response.newCheckpoint
            hasMore = response.hasMore
        }

        if currentCheckpoint != checkpoint {
            try await checkpointStore.update(projectID: project.id, checkpoint: currentCheckpoint)
        }
    }

    private func applyRemoteChanges(_ documents: [SyncDocument], project: Project) async throws {
        guard let connectionStore, let projectStore else { return }

        for doc in documents {
            switch doc.collection {
            case .connections:
                if doc.isDeleted {
                    if let existing = connectionStore.connections.first(where: { $0.id == doc.id }) {
                        try await connectionStore.deleteConnection(existing)
                    }
                } else {
                    let existing = connectionStore.connections.first { $0.id == doc.id }
                    var connection = try adapter.applyToConnection(doc, existing: existing)
                    applyEncryptedCredentials(from: doc, projectID: project.id, keychainID: &connection.keychainIdentifier, displayName: connection.connectionName)
                    try await connectionStore.updateConnection(connection)
                }

            case .folders:
                if doc.isDeleted {
                    if let existing = connectionStore.folders.first(where: { $0.id == doc.id }) {
                        try await connectionStore.deleteFolder(existing)
                    }
                } else {
                    let existing = connectionStore.folders.first { $0.id == doc.id }
                    let folder = try adapter.applyToFolder(doc, existing: existing)
                    try await connectionStore.updateFolder(folder)
                }

            case .identities:
                if doc.isDeleted {
                    if let existing = connectionStore.identities.first(where: { $0.id == doc.id }) {
                        try await connectionStore.deleteIdentity(existing)
                    }
                } else {
                    let existing = connectionStore.identities.first { $0.id == doc.id }
                    var identity = try adapter.applyToIdentity(doc, existing: existing)
                    applyEncryptedCredentials(from: doc, projectID: project.id, keychainID: &identity.keychainIdentifier, displayName: identity.name)
                    try await connectionStore.updateIdentity(identity)
                }

            case .projects:
                if !doc.isDeleted {
                    let existing = projectStore.projects.first { $0.id == doc.id }
                    let updatedProject = try adapter.applyToProject(doc, existing: existing)
                    try await projectStore.updateProject(updatedProject)
                }

            case .bookmarks:
                if !doc.isDeleted, let projectIdx = projectStore.projects.firstIndex(where: { $0.id == project.id }) {
                    let existing = projectStore.projects[projectIdx].bookmarks.first { $0.id == doc.id }
                    let bookmark = try adapter.applyToBookmark(doc, existing: existing)
                    if let bookmarkIdx = projectStore.projects[projectIdx].bookmarks.firstIndex(where: { $0.id == bookmark.id }) {
                        projectStore.projects[projectIdx].bookmarks[bookmarkIdx] = bookmark
                    } else {
                        projectStore.projects[projectIdx].bookmarks.append(bookmark)
                    }
                    try await projectStore.updateProject(projectStore.projects[projectIdx])
                } else if doc.isDeleted, let projectIdx = projectStore.projects.firstIndex(where: { $0.id == project.id }) {
                    projectStore.projects[projectIdx].bookmarks.removeAll { $0.id == doc.id }
                    try await projectStore.updateProject(projectStore.projects[projectIdx])
                }

            case .settings:
                if !doc.isDeleted, let projectIdx = projectStore.projects.firstIndex(where: { $0.id == project.id }) {
                    let settings = try adapter.applyToSettings(doc, existing: projectStore.projects[projectIdx].projectGlobalSettings)
                    projectStore.projects[projectIdx].projectGlobalSettings = settings
                    if projectStore.selectedProject?.id == project.id {
                        projectStore.globalSettings = settings
                    }
                    try await projectStore.updateProject(projectStore.projects[projectIdx])
                }
            }
        }
    }

    // MARK: - Push

    private func pushChanges(for project: Project, serverProjectID: UUID) async throws {
        guard let connectionStore, let projectStore else { return }

        let enabled = SyncPreferences.enabledCollections()
        let dirtyItems = await dirtyTracker.dirtyItems(for: project.id)
            .filter { enabled.contains($0.collection) }
        guard !dirtyItems.isEmpty else { return }

        var documents: [SyncDocument] = []
        var pushedItems: Set<DirtyItem> = []

        for item in dirtyItems {
            let hlc = clock.now()

            do {
                if item.isDelete {
                    var doc = SyncDocument(
                        id: item.id,
                        collection: item.collection,
                        projectID: item.projectID,
                        isDeleted: true,
                        deletedAt: Date()
                    )
                    // Add a tombstone field so the HLC is tracked
                    doc.fields["_deleted"] = SyncField(
                        value: Data("true".utf8),
                        hlc: hlc
                    )
                    documents.append(doc)
                    pushedItems.insert(item)
                } else {
                    switch item.collection {
                    case .connections:
                        if let conn = connectionStore.connections.first(where: { $0.id == item.id }) {
                            var doc = try adapter.toSyncDocument(conn, hlc: hlc)
                            try addEncryptedCredentials(to: &doc, keychainID: conn.keychainIdentifier, projectID: project.id, hlc: hlc)
                            documents.append(doc)
                            pushedItems.insert(item)
                        }
                    case .folders:
                        if let folder = connectionStore.folders.first(where: { $0.id == item.id }) {
                            documents.append(try adapter.toSyncDocument(folder, hlc: hlc))
                            pushedItems.insert(item)
                        }
                    case .identities:
                        if let identity = connectionStore.identities.first(where: { $0.id == item.id }) {
                            var doc = try adapter.toSyncDocument(identity, hlc: hlc)
                            try addEncryptedCredentials(to: &doc, keychainID: identity.keychainIdentifier, projectID: project.id, hlc: hlc)
                            documents.append(doc)
                            pushedItems.insert(item)
                        }
                    case .projects:
                        if let proj = projectStore.projects.first(where: { $0.id == item.id }) {
                            documents.append(try adapter.toSyncDocument(proj, hlc: hlc))
                            pushedItems.insert(item)
                        }
                    case .bookmarks:
                        if let proj = projectStore.projects.first(where: { $0.id == project.id }),
                           let bookmark = proj.bookmarks.first(where: { $0.id == item.id }) {
                            documents.append(try adapter.toSyncDocument(bookmark, projectID: project.id, hlc: hlc))
                            pushedItems.insert(item)
                        }
                    case .settings:
                        if let proj = projectStore.projects.first(where: { $0.id == project.id }),
                           let settings = proj.projectGlobalSettings {
                            documents.append(try adapter.toSyncDocument(settings: settings, projectID: project.id, hlc: hlc))
                            pushedItems.insert(item)
                        }
                    }
                }
            } catch {
                logger.error("Failed to create sync document for \(item.id): \(error.localizedDescription)")
            }
        }

        guard !documents.isEmpty else { return }

        let response = try await syncClient.push(changes: documents, projectID: serverProjectID)
        logger.info("Pushed \(response.accepted) documents")

        if !response.conflicts.isEmpty {
            logger.warning("Server reported \(response.conflicts.count) conflicts — pulling to resolve")
        }

        try await dirtyTracker.clearDirty(pushedItems)
    }

    // MARK: - E2E Credential Encryption (Push)

    /// Add encrypted password field to a sync document if E2E is active.
    private func addEncryptedCredentials(to doc: inout SyncDocument, keychainID: String?, projectID: UUID, hlc: UInt64) throws {
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
    private func applyEncryptedCredentials(from doc: SyncDocument, projectID: UUID, keychainID: inout String?, displayName: String = "") {
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
    private func uploadLocalData(for project: Project) async throws {
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
    private func deleteLocalProjectData(for project: Project) async throws {
        guard let connectionStore, let projectStore else { return }

        // Delete connections
        let projectConnections = connectionStore.connections.filter { $0.projectID == project.id }
        for conn in projectConnections {
            try await connectionStore.deleteConnection(conn)
        }

        // Delete folders
        let projectFolders = connectionStore.folders.filter { $0.projectID == project.id }
        for folder in projectFolders {
            try await connectionStore.deleteFolder(folder)
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
    private(set) var pendingCredentialConflicts: [CredentialConflict] = []

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
