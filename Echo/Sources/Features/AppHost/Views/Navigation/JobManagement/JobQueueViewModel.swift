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
    private var activityPollTask: Task<Void, Never>?
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

    internal func loadDetails() async {
        guard let jobID = selectedJobID, !jobID.isEmpty else {
            properties = nil; steps = []; schedules = []; return
        }
        isLoadingDetails = true
        defer { isLoadingDetails = false }
        do {
            let propSQL = """
            SELECT
                j.description,
                owner_name = SUSER_SNAME(j.owner_sid),
                category = c.name,
                j.enabled,
                j.start_step_id,
                j.name,
                j.notify_level_email,
                j.notify_level_eventlog,
                notify_email_operator = ISNULL(o.name, '')
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            LEFT JOIN msdb.dbo.sysoperators AS o ON o.id = j.notify_email_operator_id
            WHERE j.job_id = CONVERT(uniqueidentifier, N'\(jobID)');
            """
            let rs = try await session.simpleQuery(propSQL)
            if let row = rs.rows.first {
                let desc = row[safe: rs.index(of: "description")]
                let owner = row[safe: rs.index(of: "owner_name")]
                let category = row[safe: rs.index(of: "category")]
                let enabled = (row[safe: rs.index(of: "enabled")] ?? "0") == "1"
                let start = Int(row[safe: rs.index(of: "start_step_id")] ?? "")
                let notifyLevel = Int(row[safe: rs.index(of: "notify_level_email")] ?? "0") ?? 0
                let notifyOp = row[safe: rs.index(of: "notify_email_operator")]
                let eventlogLevel = Int(row[safe: rs.index(of: "notify_level_eventlog")] ?? "0") ?? 0
                let jobName = row[safe: rs.index(of: "name")] ?? ""
                self.properties = PropertySheet(name: jobName, description: desc, owner: owner, category: category, enabled: enabled, startStepId: start, notifyLevelEmail: notifyLevel, notifyEmailOperator: notifyOp?.isEmpty == true ? nil : notifyOp, notifyLevelEventlog: eventlogLevel)
            } else {
                self.properties = nil
            }

            let stepsSQL = """
            SELECT s.step_id, s.step_name, s.subsystem, s.database_name, s.command
            FROM msdb.dbo.sysjobsteps AS s
            INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id = s.job_id
            WHERE j.job_id = CONVERT(uniqueidentifier, N'\(jobID)')
            ORDER BY s.step_id;
            """
            let srs = try await session.simpleQuery(stepsSQL)
            let sitems: [StepRow] = srs.rows.compactMap { row in
                let id = Int(row[safe: srs.index(of: "step_id")] ?? "") ?? 0
                let name = row[safe: srs.index(of: "step_name")] ?? ""
                let subsystem = row[safe: srs.index(of: "subsystem")] ?? ""
                let db = row[safe: srs.index(of: "database_name")]
                let cmd = row[safe: srs.index(of: "command")]
                return StepRow(id: id, name: name, subsystem: subsystem, database: db, command: cmd)
            }
            self.steps = sitems

            let schedSQL = """
            SELECT sc.schedule_id, sc.name, sc.enabled, sc.freq_type, sc.freq_interval,
                   js.next_run_date, js.next_run_time
            FROM msdb.dbo.sysschedules AS sc
            INNER JOIN msdb.dbo.sysjobschedules AS js ON js.schedule_id = sc.schedule_id
            WHERE js.job_id = CONVERT(uniqueidentifier, N'\(jobID)')
            ORDER BY sc.name;
            """
            let q = try await session.simpleQuery(schedSQL)
            let sch: [ScheduleRow] = q.rows.compactMap { row in
                let id = row[safe: q.index(of: "schedule_id")] ?? UUID().uuidString
                let name = row[safe: q.index(of: "name")] ?? ""
                let enabled = (row[safe: q.index(of: "enabled")] ?? "0") == "1"
                let freq = Int(row[safe: q.index(of: "freq_type")] ?? "") ?? 0
                let freqInterval = Int(row[safe: q.index(of: "freq_interval")] ?? "") ?? 0
                let nextDate = Int(row[safe: q.index(of: "next_run_date")] ?? "") ?? 0
                let nextTime = Int(row[safe: q.index(of: "next_run_time")] ?? "") ?? 0
                let next = Self.formatAgentDateTime(nextDate, nextTime)
                return ScheduleRow(id: id, name: name, enabled: enabled, freqType: freq, freqInterval: freqInterval, next: next)
            }
            self.schedules = sch
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    internal func loadHistory(all: Bool) async {
        do {
            let jobIDFilter: String
            if !all, let jobID = selectedJobID, !jobID.isEmpty {
                jobIDFilter = "WHERE h.job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))')"
            } else {
                jobIDFilter = ""
            }
            let filter = jobIDFilter
            let sql = """
            SELECT TOP (200)
                h.instance_id,
                j.name AS job_name,
                h.step_id,
                h.step_name,
                h.run_status,
                h.message,
                h.run_date,
                h.run_time,
                h.run_duration
            FROM msdb.dbo.sysjobhistory AS h
            INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id = h.job_id
            \(filter)
            ORDER BY h.instance_id DESC;
            """
            let rs = try await session.simpleQuery(sql)
            let items: [HistoryRow] = rs.rows.compactMap { row in
                let id = Int(row[safe: rs.index(of: "instance_id")] ?? "") ?? 0
                let job = row[safe: rs.index(of: "job_name")] ?? ""
                let step = Int(row[safe: rs.index(of: "step_id")] ?? "") ?? 0
                let stepName = row[safe: rs.index(of: "step_name")] ?? ""
                let status = Int(row[safe: rs.index(of: "run_status")] ?? "") ?? 0
                let msg = row[safe: rs.index(of: "message")] ?? ""
                let rdate = Int(row[safe: rs.index(of: "run_date")] ?? "") ?? 0
                let rtime = Int(row[safe: rs.index(of: "run_time")] ?? "") ?? 0
                let dur = Int(row[safe: rs.index(of: "run_duration")] ?? "") ?? 0
                return HistoryRow(id: id, jobName: job, stepId: step, stepName: stepName, status: status, message: msg, runDate: rdate, runTime: rtime, runDuration: dur)
            }
            self.history = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Job Activity Polling

    /// Start polling the selected job's execution status.
    func startActivityPolling() {
        stopActivityPolling()
        activityPollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.checkJobActivity()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopActivityPolling() {
        activityPollTask?.cancel()
        activityPollTask = nil
    }

    func checkJobActivity() async {
        guard let mssql = session as? MSSQLSession else { return }
        let jobName = jobs.first(where: { $0.id == selectedJobID })?.name
        do {
            let agent = mssql.agent
            let running = try await agent.listRunningJobs()
            let wasRunning = isJobRunning

            let polledRunning: Bool
            if let jobName {
                polledRunning = running.contains(where: { $0.name == jobName })
            } else {
                polledRunning = false
            }

            let inGracePeriod = !polledRunning
                && jobStartedAt != nil
                && !jobSeenRunning
                && Date().timeIntervalSince(jobStartedAt!) < 8

            if polledRunning {
                jobSeenRunning = true
                isJobRunning = true
            } else if inGracePeriod {
                // Grace period: keep running state until SQL Agent confirms registration
                isJobRunning = true
            } else {
                isJobRunning = false
            }

            // Update running names, but preserve the manually-started job during grace period
            var runningNames = Set(running.map { $0.name })
            if inGracePeriod, let jobName {
                runningNames.insert(jobName)
            }
            self.runningJobNames = runningNames

            // While running, query current step activity and refresh history
            // During grace period, keep the optimistic activeStepInfo — don't overwrite it
            if isJobRunning, let jobID = selectedJobID {
                if !inGracePeriod {
                    await loadActiveStepInfo(jobID: jobID)
                }
                await loadHistory(all: false)
            } else if !polledRunning {
                activeStepInfo = nil
            }

            // When job finishes, do a full refresh
            if wasRunning && !isJobRunning {
                activeStepInfo = nil
                jobStartedAt = nil
                jobSeenRunning = false
                await loadHistory(all: false)
                await loadJobs()
            }
        } catch {
            // Ignore polling errors silently
        }
    }

    private func loadActiveStepInfo(jobID: String) async {
        do {
            let sql = """
            SELECT
                j.name AS job_name,
                a.last_executed_step_id,
                s.step_name,
                a.start_execution_date,
                a.last_executed_step_date
            FROM msdb.dbo.sysjobactivity AS a
            INNER JOIN msdb.dbo.sysjobs AS j ON j.job_id = a.job_id
            LEFT JOIN msdb.dbo.sysjobsteps AS s ON s.job_id = a.job_id AND s.step_id = a.last_executed_step_id
            WHERE a.job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))')
              AND a.start_execution_date IS NOT NULL
              AND a.stop_execution_date IS NULL
              AND a.session_id = (SELECT MAX(session_id) FROM msdb.dbo.syssessions)
            ORDER BY a.start_execution_date DESC;
            """
            let rs = try await session.simpleQuery(sql)
            if let row = rs.rows.first {
                let name = row[safe: rs.index(of: "job_name")] ?? ""
                let stepID = Int(row[safe: rs.index(of: "last_executed_step_id")] ?? "") ?? 0
                let stepName = row[safe: rs.index(of: "step_name")] ?? "Step \(stepID)"
                let startDateStr = row[safe: rs.index(of: "start_execution_date")] ?? ""
                let startDate = parseDateTime(startDateStr) ?? Date()
                activeStepInfo = ActiveStepInfo(jobName: name, stepID: stepID, stepName: stepName, startTime: startDate)
            } else {
                activeStepInfo = nil
            }
        } catch {
            // Non-critical — don't surface errors for activity polling
        }
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
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func parseDateTime(_ str: String) -> Date? {
        let formatter = DateFormatter()
        // SQL Server datetime format
        for format in ["yyyy-MM-dd HH:mm:ss.SSS", "yyyy-MM-dd HH:mm:ss", "MMM dd yyyy hh:mm:ssa", "MMM  d yyyy hh:mm:ssa"] {
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let d = formatter.date(from: str) { return d }
        }
        return nil
    }
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
