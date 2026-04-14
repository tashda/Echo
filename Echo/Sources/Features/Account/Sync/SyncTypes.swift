import Foundation

// MARK: - Sync Collection

/// Categories of data that can be synced to the cloud.
enum SyncCollection: String, Codable, Sendable, CaseIterable {
    case connections
    case folders
    case identities
    case projects
    case settings
    case bookmarks

    /// User-visible name for sync settings UI.
    var displayName: String {
        switch self {
        case .connections: "Connections"
        case .folders: "Folders"
        case .identities: "Identities"
        case .projects: "Projects"
        case .settings: "Settings"
        case .bookmarks: "Bookmarks"
        }
    }

    /// Description shown below the toggle.
    var displayDescription: String {
        switch self {
        case .connections: "Server addresses, ports, and connection options"
        case .folders: "Folder structure for organizing connections"
        case .identities: "Saved login names and identity metadata"
        case .projects: "Project names and configuration"
        case .settings: "App preferences and editor settings"
        case .bookmarks: "Saved queries and snippets"
        }
    }

    var systemImage: String {
        switch self {
        case .connections: "externaldrive"
        case .folders: "folder"
        case .identities: "person.crop.circle"
        case .projects: "square.stack.3d.up"
        case .settings: "gearshape"
        case .bookmarks: "bookmark"
        }
    }

    /// Collections the user can toggle in sync settings.
    /// Projects and folders are always synced when sync is enabled (structural requirement).
    static var userToggleable: [SyncCollection] {
        [.connections, .identities, .bookmarks, .settings]
    }
}

// MARK: - Sync Preferences

/// Tracks which collections the user wants to sync.
enum SyncPreferences {
    private static let key = "sync.enabledCollections"

    /// Collections that are always synced (structural — can't be disabled).
    private static let alwaysEnabled: Set<SyncCollection> = [.projects, .folders]

    static func isEnabled(_ collection: SyncCollection) -> Bool {
        if alwaysEnabled.contains(collection) { return true }
        let stored = UserDefaults.standard.stringArray(forKey: key)
        // Default: all enabled
        guard let stored else { return true }
        return stored.contains(collection.rawValue)
    }

    static func setEnabled(_ collection: SyncCollection, enabled: Bool) {
        var current = enabledCollections()
        if enabled {
            current.insert(collection)
        } else {
            current.remove(collection)
        }
        UserDefaults.standard.set(current.map(\.rawValue), forKey: key)
    }

    static func enabledCollections() -> Set<SyncCollection> {
        let stored = UserDefaults.standard.stringArray(forKey: key)
        guard let stored else {
            // Default: all enabled
            return Set(SyncCollection.allCases)
        }
        return Set(stored.compactMap { SyncCollection(rawValue: $0) }).union(alwaysEnabled)
    }

    // MARK: - Credential Sync Toggle

    private static let credentialSyncKey = "sync.credentialSyncEnabled"

    static var isCredentialSyncEnabled: Bool {
        // Default: true (enabled once E2E is enrolled)
        UserDefaults.standard.object(forKey: credentialSyncKey) as? Bool ?? true
    }

    static func setCredentialSyncEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: credentialSyncKey)
    }
}

// MARK: - Sync Merge Strategy

/// How to handle the first sync when both local and cloud data exist for a project.
enum SyncMergeStrategy: Sendable {
    /// Combine local and cloud data. Conflicts resolved by most recent change (LWW).
    case merge
    /// Replace local data with what's in the cloud. Local-only items are deleted.
    case useCloud
    /// Push local data to cloud, overwriting cloud versions where they conflict.
    case uploadLocal
}

enum SyncStartupAction: Sendable, Equatable {
    case none
    case promptForMerge
    case pullCloud
    case uploadLocal
}

/// Summary of data counts for a project, used to inform the merge strategy prompt.
struct SyncDataSummary: Sendable {
    let localConnections: Int
    let localIdentities: Int
    let localFolders: Int
    let localBookmarks: Int
    let cloudDocuments: Int

    var hasLocalData: Bool {
        localConnections + localIdentities + localFolders + localBookmarks > 0
    }

    var hasCloudData: Bool {
        cloudDocuments > 0
    }

    var needsMergeDecision: Bool {
        hasLocalData && hasCloudData
    }

    var localTotal: Int {
        localConnections + localIdentities + localFolders + localBookmarks
    }

    func startupAction(hasCheckpoint: Bool) -> SyncStartupAction {
        guard !hasCheckpoint else { return .none }
        if needsMergeDecision { return .promptForMerge }
        if hasCloudData { return .pullCloud }
        if hasLocalData { return .uploadLocal }
        return .none
    }
}

/// A credential conflict detected during pull — local Keychain has a different
/// password than what the cloud has for the same connection/identity.
struct CredentialConflict: Identifiable, Sendable, Equatable {
    let id: UUID
    let collection: SyncCollection
    let displayName: String
    let localPassword: String
    let cloudPassword: String
}

// MARK: - Sync Field

/// A single field within a sync document, carrying its value and the HLC
/// timestamp of the last write. The server and client both use the `hlc`
/// to determine which version wins during conflict resolution.
struct SyncField: Codable, Sendable, Equatable {
    /// JSON-encoded value. Stored as raw bytes so it can also hold
    /// encrypted blobs in Phase 3.
    var value: Data

    /// Hybrid Logical Clock timestamp of the last write to this field.
    var hlc: UInt64

    /// Whether this field's value is an opaque encrypted blob.
    /// Phase 2 always sets this to `false`. Phase 3 uses `true`
    /// for credential fields.
    var isEncrypted: Bool

    init(value: Data, hlc: UInt64, isEncrypted: Bool = false) {
        self.value = value
        self.hlc = hlc
        self.isEncrypted = isEncrypted
    }
}

// MARK: - Sync Document

/// The unit of synchronization between client and server.
///
/// Each sync document maps to one domain object (a connection, folder,
/// identity, project, or settings bundle). Fields are synced individually
/// using last-writer-wins at the field level.
struct SyncDocument: Codable, Sendable, Identifiable, Equatable {
    /// The stable UUID of the domain object this document represents.
    let id: UUID

    /// Which collection this document belongs to.
    let collection: SyncCollection

    /// The project this document belongs to. Every synced object is
    /// scoped to a project.
    let projectID: UUID

    /// Per-field values with HLC timestamps for LWW merge.
    var fields: [String: SyncField]

    /// Soft-delete flag. Deletion is just another field update.
    var isDeleted: Bool

    /// When the document was soft-deleted.
    var deletedAt: Date?

    init(
        id: UUID,
        collection: SyncCollection,
        projectID: UUID,
        fields: [String: SyncField] = [:],
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.collection = collection
        self.projectID = projectID
        self.fields = fields
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }
}

// MARK: - Sync Pull Response

/// Response from the server's `sync_pull` RPC function.
struct SyncPullResponse: Codable, Sendable {
    let documents: [SyncDocument]
    let newCheckpoint: UInt64
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case documents
        case newCheckpoint = "new_checkpoint"
        case hasMore = "has_more"
    }
}

// MARK: - Sync Push Response

/// Response from the server's `sync_push` RPC function.
struct SyncPushResponse: Codable, Sendable {
    let accepted: Int
    let conflicts: [SyncConflict]
}

/// A conflict reported by the server during push.
struct SyncConflict: Codable, Sendable {
    let id: UUID
    let serverField: String
    let serverHLC: UInt64

    enum CodingKeys: String, CodingKey {
        case id
        case serverField = "server_field"
        case serverHLC = "server_hlc"
    }
}

// MARK: - Sync Status

/// Observable sync state for UI display.
enum SyncStatus: Sendable, Equatable {
    case idle
    case syncing
    case error(String)
    case offline
    case disabled

    var isError: Bool {
        if case .error = self { return true }
        return false
    }

    var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}

// MARK: - Checkpoint Persistence

/// Persisted sync checkpoint per project. Stored locally to track
/// the last successfully pulled server HLC.
struct SyncCheckpoint: Codable, Sendable {
    var projectID: UUID
    var checkpoint: UInt64
    var lastSyncedAt: Date
}
