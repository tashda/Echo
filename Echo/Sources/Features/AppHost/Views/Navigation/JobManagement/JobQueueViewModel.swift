import SwiftUI
import Combine
import SQLServerKit

@MainActor
final class JobQueueViewModel: ObservableObject {
    struct JobRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let category: String?; let owner: String?; let lastOutcome: String?; let nextRun: String? }
    struct StepRow: Identifiable, Hashable { let id: Int; let name: String; let subsystem: String; let database: String?; let command: String? }
    struct ScheduleRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let freqType: Int; let freqInterval: Int; let next: String? }
    struct PropertySheet: Equatable { var name: String = ""; var description: String?; var owner: String?; var category: String?; var enabled: Bool; var startStepId: Int?; var notifyLevelEmail: Int = 0; var notifyEmailOperator: String?; var notifyLevelEventlog: Int = 0 }
    struct OperatorInfo: Identifiable, Hashable { let id: String; let name: String; let emailAddress: String?; let enabled: Bool }
    struct HistoryRow: Identifiable, Hashable { let id: Int; let jobName: String; let stepId: Int; let stepName: String; let status: Int; let message: String; let runDate: Int; let runTime: Int; let runDuration: Int }

    internal let session: DatabaseSession
    private let connection: SavedConnection

    @Published var jobs: [JobRow] = []
    @Published var selectedJobID: String? { didSet { Task { await loadDetailsAndHistory() } } }
    @Published var properties: PropertySheet?
    @Published var steps: [StepRow] = []
    @Published var schedules: [ScheduleRow] = []
    @Published var history: [HistoryRow] = []
    @Published var databaseNames: [String] = []
    @Published var operators: [OperatorInfo] = []
    @Published var categories: [String] = []
    @Published var selectedHistoryRowID: Int?
    @Published var isLoadingJobs = false
    @Published var isLoadingDetails = false
    @Published var isJobRunning = false
    @Published var runningJobNames: Set<String> = []
    @Published var errorMessage: String?
    @Published var activeStepInfo: ActiveStepInfo?
    internal var activityPollTask: Task<Void, Never>?
    /// Tracks when a job was manually started to avoid clearing running state during SQL Agent's registration delay
    internal var jobStartedAt: Date?
    /// Whether the poll has ever seen the job running (confirmed by SQL Agent)
    internal var jobSeenRunning = false

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

    func reloadJobs() async { await loadJobs() }

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
                next_run = CASE WHEN nx.next_run_date IS NULL THEN NULL ELSE RIGHT('00000000' + CONVERT(varchar(8), nx.next_run_date), 8) + ' ' + RIGHT('000000' + CONVERT(varchar(6), nx.next_run_time), 6) END
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            OUTER APPLY (
                SELECT TOP (1) run_status
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
                let nextRunRaw = row[safe: idx("next_run")]
                let nextRun: String? = {
                    guard let raw = nextRunRaw else { return nil }
                    let parts = raw.split(separator: " ")
                    guard parts.count == 2,
                          let dateInt = Int(parts[0]),
                          let timeInt = Int(parts[1]) else { return raw }
                    return Self.formatAgentDateTime(dateInt, timeInt)
                }()
                return JobRow(id: id, name: name, enabled: enabled, category: category, owner: owner, lastOutcome: outcome, nextRun: nextRun)
            }
            self.jobs = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadDetailsAndHistory() async {
        stopActivityPolling()
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
