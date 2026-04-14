import Foundation
import Observation
import SQLServerKit

@Observable
final class MSSQLAdvancedObjectsViewModel {

    enum Section: String, CaseIterable {
        case changeTracking = "Change Tracking"
        case cdc = "Change Data Capture"
        case fullTextSearch = "Full-Text Search"
        case replication = "Replication"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedSection: Section = .changeTracking
    var databaseName: String
    var isInitialized = false

    // MARK: - Change Tracking

    var ctStatus: [SQLServerChangeTrackingStatus] = []
    var ctTables: [SQLServerChangeTrackingClient.SQLServerCTTable] = []
    var isLoadingCT = false

    // MARK: - CDC

    var cdcTables: [SQLServerCDCTable] = []
    var isLoadingCDC = false

    // MARK: - Full-Text Search

    var ftCatalogs: [SQLServerFullTextCatalog] = []
    var ftIndexes: [SQLServerFullTextIndex] = []
    var isLoadingFT = false

    // MARK: - Replication

    var distributorConfigured = false
    var publications: [SQLServerPublication] = []
    var subscriptions: [SQLServerSubscription] = []
    var agentStatuses: [SQLServerReplicationClient.SQLServerReplicationAgentStatus] = []
    var expandedPublication: String?
    var articles: [SQLServerReplicationArticle] = []
    var isLoadingReplication = false

    // MARK: - Shared

    var errorMessage: String?
    var isBusy = false

    var canManageState: Bool {
        true // Permissions checked at operation level
    }

    var isLoadingCurrentSection: Bool {
        switch selectedSection {
        case .changeTracking: return isLoadingCT
        case .cdc: return isLoadingCDC
        case .fullTextSearch: return isLoadingFT
        case .replication: return isLoadingReplication
        }
    }

    init(session: DatabaseSession, connectionID: UUID, connectionSessionID: UUID, databaseName: String) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
        self.databaseName = databaseName
    }

    func initialize() async {
        guard !isInitialized else { return }
        await loadCurrentSection()
        isInitialized = true
    }

    func loadCurrentSection() async {
        switch selectedSection {
        case .changeTracking: await loadChangeTracking()
        case .cdc: await loadCDC()
        case .fullTextSearch: await loadFullText()
        case .replication: await loadReplication()
        }
    }
}
