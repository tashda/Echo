import Foundation
import EchoLocalStorage
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

    @ObservationIgnored let syncClient: SyncClient
    @ObservationIgnored let adapter: SyncAdapter
    @ObservationIgnored private let merger: SyncMerger
    @ObservationIgnored let checkpointStore: SyncCheckpointStore
    @ObservationIgnored let dirtyTracker: SyncDirtyTracker
    @ObservationIgnored let fieldEncryptor = E2EFieldEncryptor()

    /// E2E key store — provides project keys for credential encryption.
    @ObservationIgnored var e2eKeyStore: E2EKeyStore?
    @ObservationIgnored var clock: HybridClock

    @ObservationIgnored let logger = Logger(subsystem: "dev.echodb.echo", category: "sync")

    /// References to the app stores, set after initialization.
    @ObservationIgnored weak var connectionStore: ConnectionStore?
    @ObservationIgnored weak var projectStore: ProjectStore?

    /// Whether a sync cycle is currently running.
    @ObservationIgnored private var isSyncing = false

    var pendingCredentialConflicts: [CredentialConflict] = []

    @ObservationIgnored var accountID: String?
    @ObservationIgnored var accountEpoch = UUID()

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
        guard accountID != nil else { return }
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
        accountEpoch = UUID()
        status = .disabled
        logger.info("Sync engine stopped")
    }

    /// Checks if a different user signed in. If so, resets sync state.
    /// Same user signing back in keeps `isSyncEnabled` intact.
    func resetIfUserChanged(currentUserID: String?) async {
        guard let userID = currentUserID else { return }
        let currentUserID = userID.lowercased()

        do {
            let storedAccount = try await EncryptedRecordStore.shared.syncContext()?.account
            var previous = storedAccount
            if previous == nil { previous = try await LocalSyncImport.originalAccount() }
            if let previous, previous != currentUserID, let projectStore {
                for index in projectStore.projects.indices { projectStore.projects[index].isSyncEnabled = false }
                try await projectStore.saveProjects(projectStore.projects)
                lastSyncedAt = nil
            }
            accountEpoch = UUID()
            accountID = currentUserID
            try await EncryptedRecordStore.shared.configureSync(account: currentUserID,
                projects: Set(projectStore?.projects.filter(\.isSyncEnabled).map { $0.id.uuidString } ?? []))
            await checkpointStore.setAccount(currentUserID)
            await dirtyTracker.setAccount(currentUserID)
            UserDefaults.standard.removeObject(forKey: "sync.lastUserID")
        } catch {
            status = .error("Failed to initialize account storage")
            logger.error("Couldn't select sync account: \(error.localizedDescription)")
        }
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

        let epoch = accountEpoch
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
                guard accountEpoch == epoch, status != .disabled else { throw CancellationError() }
                try await syncProject(project)
            }
            guard accountEpoch == epoch, status != .disabled else { throw CancellationError() }

            lastSyncedAt = Date()
            status = .idle
            logger.info("Sync completed successfully")
        } catch is CancellationError {
            logger.debug("Sync cancelled")
            if accountEpoch == epoch && status != .disabled { status = .idle }
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
        guard userID.uuidString.caseInsensitiveCompare(accountID ?? "") == .orderedSame else { throw CancellationError() }
        let serverID = syncClient.serverProjectID(localID: project.id, userID: userID)

        // 1. Ensure project exists on server (using per-user server ID)
        let sortOrder = projectStore?.projects.firstIndex(where: { $0.id == project.id }) ?? 0
        try await syncClient.upsertProject(serverID: serverID, userID: userID, name: project.name, sortOrder: sortOrder)

        // Upload durable local edits first so a pull cannot overwrite work awaiting upload.
        try await pushChanges(for: project, serverProjectID: serverID)
        try await pullChanges(for: project, serverProjectID: serverID)
    }

    // MARK: - Pull

    func pullChanges(for project: Project, serverProjectID: UUID) async throws {
        let checkpoint = await checkpointStore.checkpoint(for: project.id)

        var hasMore = true
        var currentCheckpoint = checkpoint

        let epoch = accountEpoch
        while hasMore {
            guard epoch == accountEpoch, status != .disabled else { throw CancellationError() }
            let response = try await syncClient.pull(
                checkpoint: currentCheckpoint,
                projectID: serverProjectID
            )

            guard epoch == accountEpoch, status != .disabled else { throw CancellationError() }

            // Update clock from remote HLCs
            for doc in response.documents {
                let maxRemoteHLC = doc.fields.values.map(\.hlc).max() ?? 0
                clock.receive(remote: maxRemoteHLC)
            }

            // Apply remote changes to local stores (filtered by user preferences)
            let enabled = SyncPreferences.enabledCollections()
            let filtered = response.documents.filter { enabled.contains($0.collection) }.map { $0.scoped(to: project.id) }
            try await applyRemoteChanges(filtered, project: project, checkpoint: response.newCheckpoint)

            currentCheckpoint = response.newCheckpoint
            hasMore = response.hasMore
        }

    }

    // MARK: - Push

    private func pushChanges(for project: Project, serverProjectID: UUID) async throws {
        guard let connectionStore, let projectStore else { return }

        let enabled = SyncPreferences.enabledCollections()
        let dirtyItems = try await dirtyTracker.dirtyItems(for: project.id)
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

        let epoch = accountEpoch
        let response = try await syncClient.push(changes: documents, projectID: serverProjectID)
        guard epoch == accountEpoch, status != .disabled else { throw CancellationError() }
        logger.info("Pushed \(response.accepted) documents")

        if !response.conflicts.isEmpty {
            logger.warning("Server reported \(response.conflicts.count) conflicts — pulling to resolve")
        }

        // The server reports a count, not per-document success. Retain ambiguous batches for retry.
        if response.accepted == documents.count && response.conflicts.isEmpty {
            try await dirtyTracker.clearDirty(pushedItems)
        }
    }

}
