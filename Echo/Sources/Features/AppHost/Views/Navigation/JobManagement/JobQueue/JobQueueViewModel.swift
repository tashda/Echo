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
    struct HistoryRow: Identifiable, Hashable {
        let id: Int; let jobName: String; let stepId: Int; let stepName: String; let status: Int; let message: String; let runDate: Int; let runTime: Int; let runDuration: Int
        var statusLabel: String {
            switch status { case 0: return "Failed"; case 1: return "Succeeded"; case 2: return "Retry"; case 3: return "Canceled"; case 4: return "In Progress"; default: return "Unknown" }
        }
        /// Combined date+time as sortable integer: YYYYMMDDHHMMSS
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
    var selectedHistoryRowID: Int?
    var isLoadingJobs = false
    var isLoadingDetails = false
    var isJobRunning = false
    /// The name of the job the user manually started via Play — drives refresh button progress.
    /// Cleared only when that specific job stops running, regardless of selection changes.
    var manuallyStartedJobName: String?
    /// ActivityEngine handle for the manually-started job — stays alive until the job finishes.
    @ObservationIgnored var manualStartHandle: OperationHandle?
    var runningJobNames: Set<String> = []
    var errorMessage: String?
    var selectedDetailSection: String = "Properties"
    var activeStepInfo: ActiveStepInfo?
    @ObservationIgnored internal var activityPollTask: Task<Void, Never>?
    /// Tracks when a job was manually started to avoid clearing running state during SQL Agent's registration delay
    @ObservationIgnored internal var jobStartedAt: Date?
    /// Whether the poll has ever seen the job running (confirmed by SQL Agent)
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

    /// Identifier passed before jobs are loaded — may be a GUID or a job name.
    private var pendingJobIdentifier: String?

    init(session: DatabaseSession, connection: SavedConnection, initialSelectedJobID: String? = nil) {
        self.session = session
        self.connection = connection
        self.pendingJobIdentifier = initialSelectedJobID
    }

    func loadInitial() async {
        await loadJobs()
        await loadDatabaseNames()
        await loadOperators()
        await loadCategories()
        await loadLogins()

        // Resolve pending selection now that jobs are loaded
        let hadPending = pendingJobIdentifier != nil
        if let identifier = pendingJobIdentifier {
            pendingJobIdentifier = nil
            resolveAndSelect(jobIdentifier: identifier)
        }

        // If no pending selection was resolved, load all history
        if selectedJobID == nil {
            await loadHistory(all: true)
        } else if !hadPending {
            // Selection was already set before loadInitial (shouldn't happen normally)
            await loadDetailsAndHistory()
        }
        // else: resolveAndSelect already triggered didSet → loadDetailsAndHistory

        // Check if the selected job is currently running
        if selectedJobID != nil {
            await checkJobActivity()
            if isJobRunning { startActivityPolling() }
        }
    }

    /// Resolve a job identifier (GUID or name) against the loaded jobs list and select it.
    func resolveAndSelect(jobIdentifier: String) {
        let normalized = jobIdentifier
            .trimmingCharacters(in: CharacterSet(charactersIn: "{}"))

        // Try exact ID match (case-insensitive for GUIDs)
        if let match = jobs.first(where: {
            $0.id.trimmingCharacters(in: CharacterSet(charactersIn: "{}"))
                .caseInsensitiveCompare(normalized) == .orderedSame
        }) {
            if selectedJobID != match.id {
                selectedJobID = match.id
            } else {
                // Already selected — force reload details
                Task { await loadDetailsAndHistory() }
            }
            return
        }
        // Fallback: match by name
        if let match = jobs.first(where: { $0.name.caseInsensitiveCompare(normalized) == .orderedSame }) {
            if selectedJobID != match.id {
                selectedJobID = match.id
            } else {
                Task { await loadDetailsAndHistory() }
            }
            return
        }
        // If jobs aren't loaded yet, store as pending
        pendingJobIdentifier = jobIdentifier
    }

    private func loadDatabaseNames() async {
        do {
            databaseNames = try await session.listDatabases()
        } catch {
            databaseNames = []
        }
    }

    private func loadCategories() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let agent = mssql.agent
            let cats = try await agent.listCategories()
            categories = cats.filter { $0.classId == 1 }.map(\.name).sorted()
        } catch {
            categories = []
        }
    }

    private func loadOperators() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let agent = mssql.agent
            let ops = try await agent.listOperators()
            self.operators = ops.map { OperatorInfo(id: $0.name, name: $0.name, emailAddress: $0.emailAddress, enabled: $0.enabled) }
        } catch {
            self.operators = []
        }
    }

    private func loadLogins() async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let result = try await mssql.serverSecurity.listLogins()
            logins = result.map(\.name).sorted()
        } catch {
            logins = []
        }
    }

    func reloadJobs() async {
        await loadJobs()
    }

    internal func loadJobs() async {
        isLoadingJobs = true
        defer { isLoadingJobs = false }
        do {
            let sql = """
            SELECT
                job_id = CONVERT(nvarchar(36), j.job_id),
                j.name,
                j.enabled,
                owner_name = SUSER_SNAME(j.owner_sid),
                category = c.name,
                last_outcome = CASE last.run_status
                    WHEN 0 THEN 'Failed'
                    WHEN 1 THEN 'Succeeded'
                    WHEN 2 THEN 'Retry'
                    WHEN 3 THEN 'Canceled'
                    WHEN 4 THEN 'In Progress'
                    ELSE NULL
                END,
                last_run = CASE WHEN last.run_date IS NULL THEN NULL ELSE RIGHT('00000000' + CONVERT(varchar(8), last.run_date), 8) + ' ' + RIGHT('000000' + CONVERT(varchar(6), last.run_time), 6) END,
                next_run = CASE WHEN nx.next_run_date IS NULL THEN NULL ELSE RIGHT('00000000' + CONVERT(varchar(8), nx.next_run_date), 8) + ' ' + RIGHT('000000' + CONVERT(varchar(6), nx.next_run_time), 6) END
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            OUTER APPLY (
                SELECT TOP (1) run_status, run_date, run_time
                FROM msdb.dbo.sysjobhistory AS h
                WHERE h.job_id = j.job_id AND h.step_id = 0
                ORDER BY h.instance_id DESC
            ) AS last
            OUTER APPLY (
                SELECT TOP (1) js.next_run_date, js.next_run_time
                FROM msdb.dbo.sysjobschedules AS js
                WHERE js.job_id = j.job_id
                ORDER BY js.next_run_date, js.next_run_time
            ) AS nx
            ORDER BY j.name;
            """
            let rs = try await session.simpleQuery(sql)
            let idx: (String) -> Int = { name in rs.columns.firstIndex { $0.name.caseInsensitiveCompare(name) == .orderedSame } ?? 0 }
            let items = rs.rows.compactMap { row -> JobRow? in
                guard let name = row[safe: idx("name")] else { return nil }
                let id = row[safe: idx("job_id")] ?? name
                let enabled = (row[safe: idx("enabled")] ?? "0") == "1"
                let owner = row[safe: idx("owner_name")]
                let category = row[safe: idx("category")]
                let outcome = row[safe: idx("last_outcome")]
                let lastRunDate: String? = {
                    guard let raw = row[safe: idx("last_run")] else { return nil }
                    let parts = raw.split(separator: " ")
                    guard parts.count == 2, let d = Int(parts[0]), let t = Int(parts[1]) else { return raw }
                    return Self.formatAgentDateTime(d, t)
                }()
                let nextRun: String? = {
                    guard let raw = row[safe: idx("next_run")] else { return nil }
                    let parts = raw.split(separator: " ")
                    guard parts.count == 2, let d = Int(parts[0]), let t = Int(parts[1]) else { return raw }
                    return Self.formatAgentDateTime(d, t)
                }()
                return JobRow(id: id, name: name, enabled: enabled, category: category, owner: owner, lastOutcome: outcome, lastRunDate: lastRunDate, nextRun: nextRun)
            }
            self.jobs = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadDetailsAndHistory() async {
        stopActivityPolling()
        // Only reset running state if this isn't the job we manually started
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
