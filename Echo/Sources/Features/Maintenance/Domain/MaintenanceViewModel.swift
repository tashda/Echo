import Foundation
import SwiftUI
import PostgresKit

@Observable
final class MaintenanceViewModel {
    /// PostgreSQL's maintenance pages, shown in the tab (round 36.2).
    enum PostgresMaintenanceSection: String, CaseIterable {
        case health = "Health"
        case tables = "Tables"
        case indexes = "Indexes"
    }

    let connectionID: UUID
    let connectionSessionID: UUID
    let databaseType: DatabaseType
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private(set) var panelState: BottomPanelState?
    @ObservationIgnored var activityEngine: ActivityEngine?

    var selectedDatabase: String?
    var databaseList: [String] = []
    var tableStats: [PostgresMaintenanceTableStat] = []
    var indexStats: [PostgresIndexStat] = []
    var healthStats: PostgresMaintenanceHealth?
    var isLoadingTables = false
    var isLoadingIndexes = false
    var isLoadingHealth = false
    var isInitialized = false
    var pgBackupsVM: PostgresBackupRestoreViewModel?
    var requestedSection: String?
    var selectedSection: PostgresMaintenanceSection = .health

    init(
        session: DatabaseSession,
        connectionID: UUID,
        connectionSessionID: UUID,
        databaseType: DatabaseType,
        initialDatabase: String? = nil
    ) {
        self.session = session
        self.connectionID = connectionID
        self.connectionSessionID = connectionSessionID
        self.databaseType = databaseType
        self.selectedDatabase = initialDatabase
    }

    func setPanelState(_ state: BottomPanelState) {
        self.panelState = state
    }

    func logOperation(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Maintenance", duration: TimeInterval? = nil) {
        guard let panelState else { return }
        panelState.appendMessage(text, severity: severity, category: category, duration: duration)
    }

    func estimatedMemoryUsageBytes() -> Int {
        256 * 1024
    }
}
