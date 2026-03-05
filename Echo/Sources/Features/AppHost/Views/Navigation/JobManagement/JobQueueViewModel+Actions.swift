import Foundation

extension JobQueueViewModel {

    // MARK: - Actions (Jobs)

    func startSelectedJob() async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_start_job @job_id = N'\(jobID)';"
        _ = try? await session.simpleQuery(sql)
        await loadHistory(all: false)
    }

    func stopSelectedJob() async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_stop_job @job_id = N'\(jobID)';"
        _ = try? await session.simpleQuery(sql)
        await loadHistory(all: false)
    }

    func setSelectedJobEnabled(_ enabled: Bool) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_update_job @job_id = N'\(jobID)', @enabled = \(enabled ? 1 : 0);"
        _ = try? await session.simpleQuery(sql)
        await loadJobs()
    }

    // MARK: - Actions (Properties)

    func updateProperties(_ sheet: PropertySheet) async {
        guard let jobID = selectedJobID else { return }
        var parts: [String] = ["@job_id = N'\(jobID)'"]
        if let desc = sheet.description { parts.append("@description = N'\(escape(desc))'") }
        if let owner = sheet.owner { parts.append("@owner_login_name = N'\(escape(owner))'") }
        if let cat = sheet.category { parts.append("@category_name = N'\(escape(cat))'") }
        parts.append("@enabled = \(sheet.enabled ? 1 : 0)")
        if let start = sheet.startStepId, start > 0 { parts.append("@start_step_id = \(start)") }
        let sql = "EXEC msdb.dbo.sp_update_job \(parts.joined(separator: ", "));"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadJobs(); await loadDetails()
    }

    // MARK: - Actions (Steps)

    func addTSQLStep(name: String, database: String?, command: String) async {
        guard let jobID = selectedJobID else { return }
        var sql = "EXEC msdb.dbo.sp_add_jobstep @job_id = N'\(jobID)', @step_name = N'\(escape(name))', @subsystem = N'TSQL', @command = N'\(escape(command))'"
        if let db = database, !db.isEmpty { sql += ", @database_name = N'\(escape(db))'" }
        sql += ";"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    func updateTSQLStep(stepID: Int, name: String, database: String?, command: String) async {
        guard let jobID = selectedJobID else { return }
        var sql = "EXEC msdb.dbo.sp_update_jobstep @job_id = N'\(jobID)', @step_id = \(stepID), @step_name = N'\(escape(name))', @command = N'\(escape(command))'"
        if let db = database, !db.isEmpty { sql += ", @database_name = N'\(escape(db))'" }
        sql += ";"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    func deleteStep(stepID: Int) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_delete_jobstep @job_id = N'\(jobID)', @step_id = \(stepID);"
        do { _ = try await session.simpleQuery(sql) } catch { errorMessage = error.localizedDescription }
        await loadDetails()
    }

    // MARK: - Actions (Schedules)

    func addAndAttachSchedule(name: String, enabled: Bool, freqType: Int = 4, freqInterval: Int = 1) async {
        guard let jobID = selectedJobID else { return }
        let create = "EXEC msdb.dbo.sp_add_schedule @schedule_name = N'\(escape(name))', @enabled = \(enabled ? 1 : 0), @freq_type = \(freqType), @freq_interval = \(freqInterval);"
        do { _ = try await session.simpleQuery(create) } catch { errorMessage = error.localizedDescription; return }
        let lookup = try? await session.simpleQuery("SELECT schedule_id FROM msdb.dbo.sysschedules WHERE name = N'\(escape(name))'")
        let scheduleID = lookup?.rows.first?[safe: lookup!.index(of: "schedule_id")] ?? ""
        guard !scheduleID.isEmpty else { return }
        let attach = "EXEC msdb.dbo.sp_attach_schedule @job_id = N'\(jobID)', @schedule_id = \(scheduleID);"
        _ = try? await session.simpleQuery(attach)
        await loadDetails()
    }

    func detachSchedule(scheduleID: String) async {
        guard let jobID = selectedJobID else { return }
        let sql = "EXEC msdb.dbo.sp_detach_schedule @job_id = N'\(jobID)', @schedule_id = \(scheduleID);"
        _ = try? await session.simpleQuery(sql)
        await loadDetails()
    }
}
