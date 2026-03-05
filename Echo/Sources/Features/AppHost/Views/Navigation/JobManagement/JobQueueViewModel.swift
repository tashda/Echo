import SwiftUI
import Combine

@MainActor
final class JobQueueViewModel: ObservableObject {
    struct JobRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let category: String?; let owner: String?; let lastOutcome: String?; let nextRun: String? }
    struct StepRow: Identifiable, Hashable { let id: Int; let name: String; let subsystem: String; let database: String?; let command: String? }
    struct ScheduleRow: Identifiable, Hashable { let id: String; let name: String; let enabled: Bool; let freqType: Int; let next: String? }
    struct PropertySheet: Equatable { var description: String?; var owner: String?; var category: String?; var enabled: Bool; var startStepId: Int? }
    struct HistoryRow: Identifiable, Hashable { let id: Int; let jobName: String; let stepId: Int; let status: Int; let message: String; let runDate: Int; let runTime: Int; let runDuration: Int }

    internal let session: DatabaseSession
    private let connection: SavedConnection

    @Published internal(set) var jobs: [JobRow] = []
    @Published var selectedJobID: String? { didSet { Task { await loadDetailsAndHistory() } } }
    @Published var properties: PropertySheet?
    @Published internal(set) var steps: [StepRow] = []
    @Published internal(set) var schedules: [ScheduleRow] = []
    @Published internal(set) var history: [HistoryRow] = []
    @Published internal(set) var isLoadingJobs = false
    @Published internal(set) var isLoadingDetails = false
    @Published internal(set) var errorMessage: String?

    init(session: DatabaseSession, connection: SavedConnection, initialSelectedJobID: String? = nil) {
        self.session = session
        self.connection = connection
        self.selectedJobID = initialSelectedJobID
    }

    func loadInitial() async {
        await loadJobs()
        await loadHistory(all: true)
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
                let nextRun = row[safe: idx("next_run")]
                return JobRow(id: id, name: name, enabled: enabled, category: category, owner: owner, lastOutcome: outcome, nextRun: nextRun)
            }
            self.jobs = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    private func loadDetailsAndHistory() async {
        await loadDetails()
        await loadHistory(all: selectedJobID == nil)
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
                j.name
            FROM msdb.dbo.sysjobs AS j
            LEFT JOIN msdb.dbo.syscategories AS c ON c.category_id = j.category_id
            WHERE j.job_id = CONVERT(uniqueidentifier, N'\(jobID)');
            """
            let rs = try await session.simpleQuery(propSQL)
            if let row = rs.rows.first {
                let desc = row[safe: rs.index(of: "description")]
                let owner = row[safe: rs.index(of: "owner_name")]
                let category = row[safe: rs.index(of: "category")]
                let enabled = (row[safe: rs.index(of: "enabled")] ?? "0") == "1"
                let start = Int(row[safe: rs.index(of: "start_step_id")] ?? "")
                self.properties = PropertySheet(description: desc, owner: owner, category: category, enabled: enabled, startStepId: start)
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
            SELECT sc.schedule_id, sc.name, sc.enabled, sc.freq_type,
                   next_run = CASE WHEN js.next_run_date IS NULL THEN NULL ELSE RIGHT('00000000'+CONVERT(varchar(8), js.next_run_date), 8)+' '+RIGHT('000000'+CONVERT(varchar(6), js.next_run_time), 6) END
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
                let next = row[safe: q.index(of: "next_run")]
                return ScheduleRow(id: id, name: name, enabled: enabled, freqType: freq, next: next)
            }
            self.schedules = sch
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    internal func loadHistory(all: Bool) async {
        do {
            let filter = (!all && selectedJobID != nil) ? "WHERE h.job_id = CONVERT(uniqueidentifier, N'\(selectedJobID!)')" : ""
            let sql = """
            SELECT TOP (200)
                h.instance_id,
                j.name AS job_name,
                h.step_id,
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
                let status = Int(row[safe: rs.index(of: "run_status")] ?? "") ?? 0
                let msg = row[safe: rs.index(of: "message")] ?? ""
                let rdate = Int(row[safe: rs.index(of: "run_date")] ?? "") ?? 0
                let rtime = Int(row[safe: rs.index(of: "run_time")] ?? "") ?? 0
                let dur = Int(row[safe: rs.index(of: "run_duration")] ?? "") ?? 0
                return HistoryRow(id: id, jobName: job, stepId: step, status: status, message: msg, runDate: rdate, runTime: rtime, runDuration: dur)
            }
            self.history = items
        } catch {
            self.errorMessage = error.localizedDescription
        }
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
