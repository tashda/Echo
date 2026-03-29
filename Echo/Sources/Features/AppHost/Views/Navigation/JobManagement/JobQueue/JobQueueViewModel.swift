import SwiftUI
import SQLServerKit

@MainActor @Observable
final class JobQueueViewModel {
    struct JobRow: Identifiable, Hashable {
        let id: String; let name: String; let enabled: Bool; let category: String?; let owner: String?; let lastOutcome: String?; let lastRunDate: String?; let nextRun: String?
        var enabledSortKey: String { enabled ? "1" : "0" }
        var statusSortKey: String { name }
        var ownerSortKey: String { owner ?? "" }
        var categorySortKey: String { category ?? "" }
        var outcomeSortKey: String { lastOutcome ?? "" }
        var lastRunDateSortKey: String { lastRunDate ?? "" }
        var nextRunSortKey: String { nextRun ?? "" }
    }
    struct StepRow: Identifiable, Hashable { let id: Int; let name: String; let subsystem: String; let database: String?; let command: String? }
    struct ScheduleRow: Identifiable, Hashable {
        let id: String; let name: String; let enabled: Bool; let freqType: Int; let freqInterval: Int; let next: String?
        var enabledSortKey: String { enabled ? "1" : "0" }
        var nextSortKey: String { next ?? "" }
    }
    struct PropertySheet: Equatable { var name: String = ""; var description: String?; var owner: String?; var category: String?; var enabled: Bool; var startStepId: Int?; var notifyLevelEmail: Int = 0; var notifyEmailOperator: String?; var notifyLevelEventlog: Int = 0 }
    struct OperatorInfo: Identifiable, Hashable { let id: String; let name: String; let emailAddress: String?; let enabled: Bool }
    struct AlertRow: Identifiable, Hashable {
        let id: String
        let name: String
        let severity: Int?
        let messageId: Int?
        let databaseName: String?
        let enabled: Bool
        var enabledSortKey: String { enabled ? "1" : "0" }
    }
    struct ProxyRow: Identifiable, Hashable {
        let id: String
        let name: String
        let credentialName: String?
        let enabled: Bool
        var enabledSortKey: String { enabled ? "1" : "0" }
    }
    struct HistoryRow: Identifiable, Hashable {
        let id: Int; let jobName: String; let stepId: Int; let stepName: String; let status: Int; let message: String; let runDate: Int; let runTime: Int; let runDuration: Int
        var statusLabel: String {
            switch status { case 0: return "Failed"; case 1: return "Succeeded"; case 2: return "Retry"; case 3: return "Canceled"; case 4: return "In Progress"; default: return "Unknown" }
        }
        var runDateTimeSortKey: Int { runDate * 1_000_000 + runTime }
    }

    @ObservationIgnored internal let session: DatabaseSession
    @ObservationIgnored private let connection: SavedConnection
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var notificationEngine: NotificationEngine?
    @ObservationIgnored var connectionSessionID: UUID?

    var jobs: [JobRow] = []
    var selectedJobID: String? { didSet { Task { await loadDetailsAndHistory() } } }
    var properties: PropertySheet?
    var steps: [StepRow] = []
    var schedules: [ScheduleRow] = []
    var history: [HistoryRow] = []
    var databaseNames: [String] = []
    var operators: [OperatorInfo] = []
    var categories: [String] = []
    var logins: [String] = []
    var proxyNames: [String] = []
    var alerts: [AlertRow] = []
    var proxies: [ProxyRow] = []
    var selectedHistoryRowID: Int?
    var isLoadingJobs = false
    var isLoadingDetails = false
    var isJobRunning = false
    var manuallyStartedJobName: String?
    @ObservationIgnored var manualStartHandle: OperationHandle?
    var runningJobNames: Set<String> = []
    var errorMessage: String?
    var selectedDetailSection: String = "Properties"
    var activeStepInfo: ActiveStepInfo?
    @ObservationIgnored internal var activityPollTask: Task<Void, Never>?
    @ObservationIgnored internal var jobStartedAt: Date?
    @ObservationIgnored internal var jobSeenRunning = false

    struct ActiveStepInfo: Equatable {
        let jobName: String
        let stepID: Int
        let stepName: String
        let startTime: Date
    }

    var selectedHistoryRow: HistoryRow? {
        guard let id = selectedHistoryRowID else { return nil }
        return history.first { $0.id == id }
    }

    private var pendingJobIdentifier: String?

    init(session: DatabaseSession, connection: SavedConnection, initialSelectedJobID: String? = nil) {
        self.session = session
        self.connection = connection
        self.pendingJobIdentifier = initialSelectedJobID
    }

    deinit {
        activityPollTask?.cancel()
    }

    func loadInitial() async {
        await loadJobs()
        await loadDatabaseNames()
        await loadOperators()
        await loadCategories()
        await loadLogins()
        await loadProxies()
        await loadAlerts()

        let hadPending = pendingJobIdentifier != nil
        if let identifier = pendingJobIdentifier {
            pendingJobIdentifier = nil
            resolveAndSelect(jobIdentifier: identifier)
        }

        if selectedJobID == nil {
            await loadHistory(all: true)
        } else if !hadPending {
            await loadDetailsAndHistory()
        }

        if selectedJobID != nil {
            await checkJobActivity()
            if isJobRunning { startActivityPolling() }
        }
    }

    func resolveAndSelect(jobIdentifier: String) {
        let normalized = jobIdentifier.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
        if let match = jobs.first(where: {
            $0.id.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            if selectedJobID != match.id { selectedJobID = match.id }
            else { Task { await loadDetailsAndHistory() } }
            return
        }
        if let match = jobs.first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) {
            if selectedJobID != match.id { selectedJobID = match.id }
            else { Task { await loadDetailsAndHistory() } }
            return
        }
        pendingJobIdentifier = jobIdentifier
    }

    private func loadDatabaseNames() async {
        do { databaseNames = try await session.listDatabases() }
        catch { databaseNames = [] }
    }

    func loadCategories() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let cats = try await mssql.agent.listCategories()
            categories = cats.filter { $0.classId == 1 }.map(\.name).sorted()
        } catch { categories = [] }
    }

    private func loadOperators() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let ops = try await mssql.agent.listOperators()
            self.operators = ops.map { OperatorInfo(id: $0.name, name: $0.name, emailAddress: $0.emailAddress, enabled: $0.enabled) }
        } catch { self.operators = [] }
    }

    private func loadLogins() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let result = try await mssql.serverSecurity.listLogins()
            logins = result.map(\.name).sorted()
        } catch { logins = [] }
    }

    func loadProxies() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let result = try await mssql.agent.listProxies()
            proxyNames = result.map(\.name).sorted()
            proxies = result.map { p in
                ProxyRow(id: p.name, name: p.name, credentialName: p.credentialName, enabled: p.enabled)
            }
        } catch {
            proxyNames = []
            proxies = []
        }
    }

    func loadAlerts() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let result = try await mssql.agent.listAlerts()
            alerts = result.map { a in
                AlertRow(id: a.name, name: a.name, severity: a.severity, messageId: a.messageId, databaseName: a.databaseName, enabled: a.enabled)
            }
        } catch { alerts = [] }
    }

    func reloadJobs() async {
        await loadJobs()
    }

    // MARK: - Load Jobs (typed API)

    internal func loadJobs() async {
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingJobs = true
        defer { isLoadingJobs = false }
        do {
            let detailed = try await mssql.agent.listJobsDetailed()
            self.jobs = detailed.map { job in
                JobRow(
                    id: job.jobId,
                    name: job.name,
                    enabled: job.enabled,
                    category: job.categoryName,
                    owner: job.ownerLoginName,
                    lastOutcome: job.lastRunOutcome,
                    lastRunDate: job.lastRunDate.map { Self.formatDate($0) },
                    nextRun: job.nextRunDate.map { Self.formatDate($0) }
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadDetailsAndHistory() async {
        stopActivityPolling()
        let selectedName = jobs.first(where: { $0.id == selectedJobID })?.name
        let isManuallyStartedJob = selectedName != nil && selectedName == manuallyStartedJobName
        if !isManuallyStartedJob {
            isJobRunning = false
            activeStepInfo = nil
        }
        await loadDetails()
        await loadHistory(all: selectedJobID == nil || selectedJobID?.isEmpty == true)
        await checkJobActivity()
        if isJobRunning { startActivityPolling() }
    }

    // MARK: - Date Formatting

    private static let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt
    }()

    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Format SQL Server Agent date (YYYYMMDD) + time (HHMMSS) integers into a readable string.
    static func formatAgentDateTime(_ dateInt: Int, _ timeInt: Int) -> String? {
        guard dateInt > 0 else { return nil }
        let yyyy = dateInt / 10000
        let mm = (dateInt / 100) % 100
        let dd = dateInt % 100
        let hh = timeInt / 10000
        let mi = (timeInt / 100) % 100
        let ss = timeInt % 100
        let comps = DateComponents(year: yyyy, month: mm, day: dd, hour: hh, minute: mi, second: ss)
        guard let date = Calendar(identifier: .gregorian).date(from: comps) else { return nil }
        return dateFormatter.string(from: date)
    }

    // MARK: - Util
    internal func escape(_ s: String) -> String { s.replacingOccurrences(of: "'", with: "''") }
}

extension QueryResultSet {
    internal func index(of name: String) -> Int { columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0 }
}

extension Array where Element == String? {
    internal subscript(safe index: Int) -> String? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
