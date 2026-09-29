import Foundation
import SQLServerKit

/// Where a folder's items come from. Each source is loaded by one loader (through the typed
/// package APIs) and fills the item lists of one or more kinds.
nonisolated enum ExplorerChildSource: String, Sendable, CaseIterable {
    case serverSecurity
    case databaseSnapshots
    case agentJobs
    case integrationServices
    case linkedServers
    case serverTriggers
    case databaseSecurity
    case databaseTriggers
    case serviceBroker
    case externalResources

    /// Sources that belong to one database rather than the whole server.
    var isPerDatabase: Bool {
        switch self {
        case .databaseSecurity, .databaseTriggers, .serviceBroker, .externalResources: true
        default: false
        }
    }
}

/// Which source, for which server (and database).
struct ExplorerSourceKey: Hashable {
    let connectionID: UUID
    let databaseName: String?
    let source: ExplorerChildSource

    init(connectionID: UUID, databaseName: String? = nil, source: ExplorerChildSource) {
        self.connectionID = connectionID
        self.databaseName = source.isPerDatabase ? databaseName : nil
        self.source = source
    }
}

/// What a source has loaded so far.
struct ExplorerSourceState {
    var isLoading = false
    var hasLoaded = false
    /// Items by the folder kind that lists them (logins under `.logins`, and so on).
    var items: [ExplorerNodeKind: [ExplorerItem]] = [:]

    var needsLoad: Bool { !hasLoaded && !isLoading }
}

/// One loaded item: a login, a job, a snapshot, a queue… The loader decides how it reads
/// (name, detail, symbol, whether it's dimmed); `payload` keeps what its menu acts on.
struct ExplorerItem: Identifiable {
    enum Payload {
        case plain
        case login(type: String)
        case serverRole(isFixed: Bool)
        case credential(identity: String)
        case snapshot(SQLServerDatabaseSnapshot)
        case ssisFolder(SQLServerSSISFolder)
        case linkedServer
        case serverTrigger
    }

    let id: String
    let name: String
    var detail: String?
    var isDisabled = false
    /// A symbol other than the kind's own, such as a disabled login's.
    var symbol: String?
    /// A colour role other than the kind's own.
    var role: ExplorerIconRole?
    var payload: Payload = .plain
}
