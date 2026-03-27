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
        case postgresSecurity
        case serverSecurity
        case errorLog
        case profiler
        case resourceGovernor
        case serverProperties
        case tuningAdvisor
        case policyManagement
        case tableData
        case postgresAdvancedObjects
        case schemaDiff
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
        case postgresSecurity(PostgresDatabaseSecurityViewModel)
        case serverSecurity(ServerSecurityViewModel)
        case errorLog(ErrorLogViewModel)
        case profiler(ProfilerViewModel)
        case resourceGovernor(ResourceGovernorViewModel)
        case serverProperties(ServerPropertiesViewModel)
        case tuningAdvisor(TuningAdvisorViewModel)
        case policyManagement(PolicyManagementViewModel)
        case tableData(TableDataViewModel)
        case postgresAdvancedObjects(PostgresAdvancedObjectsViewModel)
        case schemaDiff(SchemaDiffViewModel)
    }

    let id = UUID()
    @ObservationIgnored let connection: SavedConnection
    @ObservationIgnored private(set) var session: DatabaseSession
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored private(set) var ownsSession: Bool
    /// Waiters for the dedicated session upgrade. Resolved when `upgradeToDedicatedSession` is called,
    /// or rejected when `markDedicatedSessionFailed` is called.
    @ObservationIgnored private var sessionUpgradeWaiters: [CheckedContinuation<DatabaseSession, any Error>] = []
    /// Whether a dedicated session upgrade is in progress.
    @ObservationIgnored private(set) var isAwaitingDedicatedSession: Bool = false
    /// Error message when dedicated session creation failed. Non-nil means the tab
    /// has no isolated connection and query execution should be blocked.
    var dedicatedSessionError: String?

    var isDedicatedSessionFailed: Bool { dedicatedSessionError != nil }

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
        dedicatedSessionError = nil
        // Resume any waiters blocked on the upgrade
        let waiters = sessionUpgradeWaiters
        sessionUpgradeWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: dedicatedSession)
        }
    }

    /// Marks the dedicated session as failed. Blocks query execution until retry succeeds.
    func markDedicatedSessionFailed(_ message: String) {
        dedicatedSessionError = message
        isAwaitingDedicatedSession = false
        // Reject any waiters blocked on the upgrade
        let waiters = sessionUpgradeWaiters
        sessionUpgradeWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(throwing: DedicatedSessionError.connectionFailed(message))
        }
    }

    /// Returns the dedicated session, waiting for the background upgrade if still in progress.
    /// Throws if the dedicated session fails to establish.
    func awaitDedicatedSession() async throws -> DatabaseSession {
        if !isAwaitingDedicatedSession {
            if let error = dedicatedSessionError {
                throw DedicatedSessionError.connectionFailed(error)
            }
            return session
        }
        return try await withCheckedThrowingContinuation { continuation in
            if !isAwaitingDedicatedSession {
                if let error = dedicatedSessionError {
                    continuation.resume(throwing: DedicatedSessionError.connectionFailed(error))
                } else {
                    continuation.resume(returning: session)
                }
            } else {
                sessionUpgradeWaiters.append(continuation)
            }
        }
    }

    enum DedicatedSessionError: LocalizedError {
        case connectionFailed(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let message): message
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
        case .postgresSecurity: return .postgresSecurity
        case .serverSecurity: return .serverSecurity
        case .errorLog: return .errorLog
        case .profiler: return .profiler
        case .resourceGovernor: return .resourceGovernor
        case .serverProperties: return .serverProperties
        case .tuningAdvisor: return .tuningAdvisor
        case .policyManagement: return .policyManagement
        case .tableData: return .tableData
        case .postgresAdvancedObjects: return .postgresAdvancedObjects
        case .schemaDiff: return .schemaDiff
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

    var postgresSecurity: PostgresDatabaseSecurityViewModel? {
        if case .postgresSecurity(let vm) = content { return vm }
        return nil
    }

    var serverSecurity: ServerSecurityViewModel? {
        if case .serverSecurity(let vm) = content { return vm }
        return nil
    }

    var errorLogVM: ErrorLogViewModel? {
        if case .errorLog(let vm) = content { return vm }
        return nil
    }

    var profilerVM: ProfilerViewModel? {
        if case .profiler(let vm) = content { return vm }
        return nil
    }

    var resourceGovernorVM: ResourceGovernorViewModel? {
        if case .resourceGovernor(let vm) = content { return vm }
        return nil
    }

    var serverPropertiesVM: ServerPropertiesViewModel? {
        if case .serverProperties(let vm) = content { return vm }
        return nil
    }

    var tuningAdvisorVM: TuningAdvisorViewModel? {
        if case .tuningAdvisor(let vm) = content { return vm }
        return nil
    }

    var policyManagementVM: PolicyManagementViewModel? {
        if case .policyManagement(let vm) = content { return vm }
        return nil
    }

    var tableDataVM: TableDataViewModel? {
        if case .tableData(let vm) = content { return vm }
        return nil
    }

    var postgresAdvancedObjectsVM: PostgresAdvancedObjectsViewModel? {
        if case .postgresAdvancedObjects(let vm) = content { return vm }
        return nil
    }

    var schemaDiffVM: SchemaDiffViewModel? {
        if case .schemaDiff(let vm) = content { return vm }
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
        case .databaseSecurity, .postgresSecurity, .serverSecurity, .postgresAdvancedObjects, .schemaDiff:
            return baseOverhead + 256 * 1024
        case .errorLog:
            return baseOverhead + 256 * 1024
        case .profiler:
            return baseOverhead + 1024 * 1024
        case .resourceGovernor:
            return baseOverhead + 1024 * 1024
        case .serverProperties:
            return baseOverhead + 1024 * 1024
        case .tuningAdvisor:
            return baseOverhead + 1024 * 1024
        case .policyManagement:
            return baseOverhead + 1024 * 1024
        case .tableData(let vm):
            return baseOverhead + vm.estimatedMemoryUsageBytes()
        }
    }

    private static func makePanelState(for content: Content) -> BottomPanelState {
        switch content {
        case .query:
            return .forQueryTab()
        case .maintenance, .mssqlMaintenance, .databaseSecurity, .postgresSecurity, .serverSecurity, .errorLog, .resourceGovernor, .serverProperties, .tuningAdvisor, .policyManagement, .tableData, .postgresAdvancedObjects, .schemaDiff:
            return .forMaintenanceTab()
        case .extendedEvents, .profiler:
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
