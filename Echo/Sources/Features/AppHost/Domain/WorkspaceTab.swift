import Foundation
import SwiftUI
import Observation

@Observable @MainActor
final class WorkspaceTab: Identifiable {
    struct BookmarkTabContext: Equatable {
        let bookmarkID: UUID
        let displayName: String
        let originalQuery: String

        init(bookmarkID: UUID, displayName: String, originalQuery: String) {
            self.bookmarkID = bookmarkID
            self.displayName = displayName
            self.originalQuery = originalQuery
        }

        init(bookmark: Bookmark) {
            self.bookmarkID = bookmark.id
            self.displayName = bookmark.primaryLine
            self.originalQuery = bookmark.query
        }
    }

    enum Kind: CaseIterable {
        case query
        case structure
        case diagram
        case jobQueue
        case psql
        case extensionStructure
        case extensionsManager
        case activityMonitor
        case maintenance
        case mssqlMaintenance
        case queryStore
        case extendedEvents
        case availabilityGroups
        case databaseSecurity
        case serverSecurity
    }

    enum Content {
        case query(QueryEditorState)
        case structure(TableStructureEditorViewModel)
        case diagram(SchemaDiagramViewModel)
        case jobQueue(JobQueueViewModel)
        case psql(PSQLTabViewModel)
        case extensionStructure(PostgresExtensionStructureViewModel)
        case extensionsManager(PostgresExtensionsViewModel)
        case activityMonitor(ActivityMonitorViewModel)
        case maintenance(MaintenanceViewModel)
        case mssqlMaintenance(MSSQLMaintenanceViewModel)
        case queryStore(QueryStoreViewModel)
        case extendedEvents(ExtendedEventsViewModel)
        case availabilityGroups(AvailabilityGroupsViewModel)
        case databaseSecurity(DatabaseSecurityViewModel)
        case serverSecurity(ServerSecurityViewModel)
    }

    let id = UUID()
    @ObservationIgnored let connection: SavedConnection
    @ObservationIgnored private(set) var session: DatabaseSession
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored private(set) var ownsSession: Bool
    /// Waiters for the dedicated session upgrade. Resolved when `upgradeToDedicatedSession` is called.
    @ObservationIgnored private var sessionUpgradeWaiters: [CheckedContinuation<DatabaseSession, Never>] = []
    /// Whether a dedicated session upgrade is in progress.
    @ObservationIgnored private(set) var isAwaitingDedicatedSession: Bool = false

    var title: String
    private(set) var content: Content
    var isPinned: Bool
    var activeDatabaseName: String?
    @ObservationIgnored let bookmarkContext: BookmarkTabContext?

    @ObservationIgnored let resultsGridState = QueryResultsGridState()
    let panelState: BottomPanelState

    /// Wired by the container view — allows toolbar buttons to trigger query execution
    /// on this tab without fragile closure capture chains.
    @ObservationIgnored var executeQueryAction: ((String) async -> Void)?

    init(
        connection: SavedConnection,
        session: DatabaseSession,
        connectionSessionID: UUID,
        title: String,
        content: Content,
        isPinned: Bool = false,
        activeDatabaseName: String? = nil,
        bookmarkContext: BookmarkTabContext? = nil,
        ownsSession: Bool = false
    ) {
        self.connection = connection
        self.session = session
        self.connectionSessionID = connectionSessionID
        self.ownsSession = ownsSession
        self.title = title
        self.content = content
        self.isPinned = isPinned
        self.activeDatabaseName = activeDatabaseName
        self.bookmarkContext = bookmarkContext
        self.panelState = Self.makePanelState(for: content)
        setupRowCountRefreshHandler()
    }

    /// Marks this tab as expecting a dedicated session upgrade.
    func markAwaitingDedicatedSession() {
        isAwaitingDedicatedSession = true
    }

    /// Replaces the shared metadata session with a dedicated query session once
    /// the background connection completes. Called for MSSQL tabs where the
    /// dedicated connection is established asynchronously after the tab appears.
    func upgradeToDedicatedSession(_ dedicatedSession: DatabaseSession) {
        session = dedicatedSession
        ownsSession = true
        isAwaitingDedicatedSession = false
        // Resume any waiters blocked on the upgrade
        let waiters = sessionUpgradeWaiters
        sessionUpgradeWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: dedicatedSession)
        }
    }

    /// Returns the dedicated session, waiting for the background upgrade if still in progress.
    /// If no upgrade is pending, returns the current session immediately.
    func awaitDedicatedSession() async -> DatabaseSession {
        if !isAwaitingDedicatedSession { return session }
        return await withCheckedContinuation { continuation in
            if !isAwaitingDedicatedSession {
                // Upgrade completed between the check and here
                continuation.resume(returning: session)
            } else {
                sessionUpgradeWaiters.append(continuation)
            }
        }
    }

    var kind: Kind {
        switch content {
        case .query: return .query
        case .structure: return .structure
        case .diagram: return .diagram
        case .jobQueue: return .jobQueue
        case .psql: return .psql
        case .extensionStructure: return .extensionStructure
        case .extensionsManager: return .extensionsManager
        case .activityMonitor: return .activityMonitor
        case .maintenance: return .maintenance
        case .mssqlMaintenance: return .mssqlMaintenance
        case .queryStore: return .queryStore
        case .extendedEvents: return .extendedEvents
        case .availabilityGroups: return .availabilityGroups
        case .databaseSecurity: return .databaseSecurity
        case .serverSecurity: return .serverSecurity
        }
    }

    var query: QueryEditorState? {
        if case .query(let state) = content { return state }
        return nil
    }

    var structureEditor: TableStructureEditorViewModel? {
        if case .structure(let editor) = content { return editor }
        return nil
    }

    var extensionStructure: PostgresExtensionStructureViewModel? {
        if case .extensionStructure(let vm) = content { return vm }
        return nil
    }

    var extensionsManager: PostgresExtensionsViewModel? {
        if case .extensionsManager(let vm) = content { return vm }
        return nil
    }

    var diagram: SchemaDiagramViewModel? {
        if case .diagram(let diagram) = content { return diagram }
        return nil
    }

    var jobQueue: JobQueueViewModel? {
        if case .jobQueue(let vm) = content { return vm }
        return nil
    }

    var psql: PSQLTabViewModel? {
        if case .psql(let vm) = content { return vm }
        return nil
    }

    var activityMonitor: ActivityMonitorViewModel? {
        if case .activityMonitor(let vm) = content { return vm }
        return nil
    }

    var maintenance: MaintenanceViewModel? {
        if case .maintenance(let vm) = content { return vm }
        return nil
    }

    var mssqlMaintenance: MSSQLMaintenanceViewModel? {
        if case .mssqlMaintenance(let vm) = content { return vm }
        return nil
    }

    var queryStoreVM: QueryStoreViewModel? {
        if case .queryStore(let vm) = content { return vm }
        return nil
    }

    var extendedEventsVM: ExtendedEventsViewModel? {
        if case .extendedEvents(let vm) = content { return vm }
        return nil
    }

    var availabilityGroupsVM: AvailabilityGroupsViewModel? {
        if case .availabilityGroups(let vm) = content { return vm }
        return nil
    }

    var databaseSecurity: DatabaseSecurityViewModel? {
        if case .databaseSecurity(let vm) = content { return vm }
        return nil
    }

    var serverSecurity: ServerSecurityViewModel? {
        if case .serverSecurity(let vm) = content { return vm }
        return nil
    }

    func setContent(_ newContent: Content) {
        content = newContent
        setupRowCountRefreshHandler()
    }

    func estimatedMemoryUsageBytes() -> Int {
        let baseOverhead = 96 * 1024
        switch content {
        case .query(let state):
            return baseOverhead + state.estimatedMemoryUsageBytes()
        case .structure(let editor):
            return baseOverhead + editor.estimatedMemoryUsageBytes()
        case .diagram(let diagram):
            return baseOverhead + diagram.estimatedMemoryUsageBytes()
        case .jobQueue:
            return baseOverhead
        case .psql(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .extensionStructure(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .extensionsManager(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .activityMonitor:
            return baseOverhead + 1024 * 1024
        case .maintenance(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .mssqlMaintenance:
            return baseOverhead + 256 * 1024 // Default estimation
        case .queryStore(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .extendedEvents(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .availabilityGroups(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        case .databaseSecurity, .serverSecurity:
            return baseOverhead + 256 * 1024
        }
    }

    private static func makePanelState(for content: Content) -> BottomPanelState {
        switch content {
        case .query:
            return .forQueryTab()
        case .maintenance, .mssqlMaintenance, .databaseSecurity, .serverSecurity:
            return .forMaintenanceTab()
        case .extendedEvents:
            return .forExtendedEventsTab()
        default:
            return .forGenericTab()
        }
    }

    private func setupRowCountRefreshHandler() {
        if case .query(let state) = content {
            state.rowCountRefreshHandler = { [weak self] in
                self?.resultsGridState.scheduleRowCountRefresh()
            }
        }
    }
}
