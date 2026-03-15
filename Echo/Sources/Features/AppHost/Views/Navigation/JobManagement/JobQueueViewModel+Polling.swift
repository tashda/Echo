import Foundation
import SQLServerKit

extension JobQueueViewModel {

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

    func loadActiveStepInfo(jobID: String) async {
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

    func parseDateTime(_ str: String) -> Date? {
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
