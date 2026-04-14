import Foundation
import SQLServerKit

@Observable
final class ErrorLogViewModel {
    enum LogProduct: String, CaseIterable, Identifiable {
        case sqlServer = "SQL Server"
        case agent = "SQL Agent"

        var id: String { rawValue }

        var nioProduct: SQLServerErrorLogProduct {
            switch self {
            case .sqlServer: return .sqlServer
            case .agent: return .agent
            }
        }
    }

    var logEntries: [SQLServerErrorLogEntry] = []
    var archives: [SQLServerErrorLogArchive] = []
    var selectedArchive: Int = 0
    var selectedProduct: LogProduct = .sqlServer
    var searchText: String = ""
    var isLoading: Bool = false
    var isInitialized: Bool = false
    var errorMessage: String?
    var selectedEntryIDs: Set<UUID> = []

    /// Archives sorted by number (0 = current first, then ascending).
    var sortedArchives: [SQLServerErrorLogArchive] {
        archives.sorted { $0.archiveNumber < $1.archiveNumber }
    }

    /// Cached entries per product to avoid reloading when switching.
    private var cachedSQLServerEntries: [SQLServerErrorLogEntry] = []
    private var cachedAgentEntries: [SQLServerErrorLogEntry] = []
    private var cachedSQLServerArchives: [SQLServerErrorLogArchive] = []
    private var cachedAgentArchives: [SQLServerErrorLogArchive] = []
    private var lastSQLServerArchive: Int = 0
    private var lastAgentArchive: Int = 0

    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored let connectionSessionID: UUID
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    /// Client-side filtering across all three columns.
    var filteredEntries: [SQLServerErrorLogEntry] {
        guard !searchText.isEmpty else { return logEntries }
        let query = searchText.lowercased()
        return logEntries.filter { entry in
            entry.text.lowercased().contains(query) ||
            (entry.processInfo?.lowercased().contains(query) ?? false) ||
            (entry.logDate?.lowercased().contains(query) ?? false)
        }
    }

    var selectedEntry: SQLServerErrorLogEntry? {
        guard let id = selectedEntryIDs.first else { return nil }
        return logEntries.first { $0.id == id }
    }

    init(session: DatabaseSession, connectionSessionID: UUID) {
        self.session = session
        self.connectionSessionID = connectionSessionID
    }

    func initialLoad() async {
        guard !isInitialized else { return }
        await loadArchives()
        await loadEntries()
        isInitialized = true
    }

    func switchProduct(to product: LogProduct) async {
        guard product != selectedProduct else { return }
        saveToCacheForCurrentProduct()
        selectedProduct = product
        restoreFromCacheForCurrentProduct()
        selectedEntryIDs = []
        await loadArchives()
        await loadEntries()
    }

    func loadArchives() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            archives = try await mssql.errorLog.listErrorLogs(product: selectedProduct.nioProduct)
        } catch {
            archives = []
        }
        // Clamp selection to a valid archive.
        if !archives.isEmpty && !archives.contains(where: { $0.archiveNumber == selectedArchive }) {
            selectedArchive = archives.first?.archiveNumber ?? 0
        }
    }

    func loadEntries() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoading = true
        errorMessage = nil
        let handle = activityEngine?.begin("Loading error log", connectionSessionID: connectionSessionID)
        do {
            logEntries = try await mssql.errorLog.getErrorLogEntries(
                archiveNumber: selectedArchive,
                product: selectedProduct.nioProduct
            )
            saveToCacheForCurrentProduct()
            handle?.succeed()
        } catch {
            errorMessage = error.localizedDescription
            logEntries = []
            handle?.fail(error.localizedDescription)
        }
        isLoading = false
    }

    func refresh() async {
        await loadArchives()
        await loadEntries()
    }

    func cycleLog() async {
        guard let mssql = session as? MSSQLSession else { return }
        let handle = activityEngine?.begin("Cycling error log", connectionSessionID: connectionSessionID)
        do {
            try await mssql.errorLog.cycleErrorLog()
            handle?.succeed()
            notificationEngine?.post(category: .maintenanceCompleted, message: "Error log cycled successfully")
            await refresh()
        } catch {
            handle?.fail(error.localizedDescription)
            notificationEngine?.post(category: .maintenanceFailed, message: "Failed to cycle error log: \(error.localizedDescription)")
        }
    }

    // MARK: - Product Cache

    private func saveToCacheForCurrentProduct() {
        switch selectedProduct {
        case .sqlServer:
            cachedSQLServerEntries = logEntries
            cachedSQLServerArchives = archives
            lastSQLServerArchive = selectedArchive
        case .agent:
            cachedAgentEntries = logEntries
            cachedAgentArchives = archives
            lastAgentArchive = selectedArchive
        }
    }

    private func restoreFromCacheForCurrentProduct() {
        switch selectedProduct {
        case .sqlServer:
            logEntries = cachedSQLServerEntries
            archives = cachedSQLServerArchives
            selectedArchive = lastSQLServerArchive
        case .agent:
            logEntries = cachedAgentEntries
            archives = cachedAgentArchives
            selectedArchive = lastAgentArchive
        }
        // Ensure selectedArchive has a valid tag in the archive list.
        if !archives.isEmpty && !archives.contains(where: { $0.archiveNumber == selectedArchive }) {
            selectedArchive = archives.first?.archiveNumber ?? 0
        }
    }
}
