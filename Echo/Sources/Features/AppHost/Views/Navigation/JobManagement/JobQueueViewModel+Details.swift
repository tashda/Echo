import Foundation

extension JobQueueViewModel {

    // MARK: - Load Details

    func loadDetails() async {
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

    // MARK: - Load History

    func loadHistory(all: Bool) async {
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
}
