import Foundation
import SwiftUI
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Agent Client

    func withAgentClient<T>(_ body: (SQLServerAgentClient) async throws -> T) async throws -> T {
        guard let mssql = session as? MSSQLSession else {
            throw AgentActionError.notMSSQL
        }
        let agent = mssql.makeAgentClient()
        return try await body(agent)
    }

    private func performAction(_ action: @escaping (SQLServerAgentClient) async throws -> Void) async {
        do {
            try await withAgentClient { agent in
                try await action(agent)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Job Name Lookup

    private func selectedJobName() -> String? {
        guard let jobID = selectedJobID, !jobID.isEmpty else { return nil }
        return jobs.first(where: { $0.id == jobID })?.name
    }

    // MARK: - Actions (Jobs)

    func startSelectedJob() async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        // Immediate visual feedback
        isJobRunning = true
        jobStartedAt = Date()
        jobSeenRunning = false
        runningJobNames.insert(jobName)
        activeStepInfo = ActiveStepInfo(jobName: jobName, stepID: 0, stepName: "Starting…", startTime: Date())

        await performAction { agent in
            try await agent.startJob(named: jobName)
        }

        // Start polling after a brief delay so SQL Agent has time to register the job
        startActivityPolling()
        await loadHistory(all: false)
    }

    func stopSelectedJob() async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        await performAction { agent in
            try await agent.stopJob(named: jobName)
        }
        isJobRunning = false
        await loadHistory(all: false)
    }

    func setSelectedJobEnabled(_ enabled: Bool) async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        await performAction { agent in
            try await agent.enableJob(named: jobName, enabled: enabled)
        }
        await loadJobs()
        await loadDetails()
    }

    // MARK: - Actions (Properties)

    func updateProperties(_ sheet: PropertySheet) async {
        guard let currentName = selectedJobName() else { return }
        let newName = sheet.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let isRenaming = !newName.isEmpty && newName != currentName

        await performAction { agent in
            try await agent.updateJob(
                named: currentName,
                description: sheet.description,
                ownerLoginName: sheet.owner,
                categoryName: sheet.category,
                enabled: sheet.enabled,
                startStepId: sheet.startStepId
            )
        }

        // Rename separately after other updates (uses the old name)
        if isRenaming {
            await performAction { agent in
                try await agent.renameJob(named: currentName, to: newName)
            }
        }

        await loadJobs(); await loadDetails()
    }

    // MARK: - Actions (Steps)

    func addStep(name: String, subsystem: String, database: String?, command: String) async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        let previousStepCount = steps.count
        await performAction { agent in
            try await agent.addStep(
                jobName: jobName,
                stepName: name,
                subsystem: subsystem,
                command: command,
                database: database
            )
            // If there were existing steps, set the previous last step to "Go to next step"
            // so multi-step jobs execute all steps in sequence
            if previousStepCount > 0, let lastStep = self.steps.last {
                _ = try await agent.configureStep(
                    jobName: jobName,
                    stepName: lastStep.name,
                    onSuccessAction: 3  // Go to next step
                ).get()
            }
        }
        await loadDetails()
    }

    func updateStep(stepName: String, newCommand: String, database: String?) async {
        guard let jobName = selectedJobName() else { return }
        await performAction { agent in
            try await agent.updateTSQLStep(
                jobName: jobName,
                stepName: stepName,
                newCommand: newCommand,
                database: database
            )
        }
        await loadDetails()
    }

    func deleteStep(stepName: String) async {
        guard let jobName = selectedJobName() else { return }
        await performAction { agent in
            try await agent.deleteStep(jobName: jobName, stepName: stepName)
        }
        await loadDetails()
    }

    // MARK: - Actions (Schedules)

    func addAndAttachSchedule(
        name: String,
        enabled: Bool,
        freqType: Int,
        freqInterval: Int,
        activeStartTime: Int? = nil,
        freqRecurrenceFactor: Int? = nil,
        activeStartDate: Int? = nil
    ) async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        await performAction { agent in
            try await agent.createSchedule(
                named: name,
                enabled: enabled,
                freqType: freqType,
                freqInterval: freqInterval,
                activeStartDate: activeStartDate,
                activeStartTime: activeStartTime,
                freqRecurrenceFactor: freqRecurrenceFactor
            )
            try await agent.attachSchedule(scheduleName: name, toJob: jobName)
        }
        await loadDetails()
    }

    // MARK: - Actions (Notifications)

    func setNotification(operatorName: String, level: Int, eventLogLevel: Int) async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        await performAction { agent in
            try await agent.setJobEmailNotification(
                jobName: jobName,
                operatorName: operatorName.isEmpty ? nil : operatorName,
                notifyLevel: level
            )
        }
        // Set event log level separately via direct SQL
        if let jobID = selectedJobID {
            do {
                let sql = "EXEC msdb.dbo.sp_update_job @job_id = N'\(escape(jobID))', @notify_level_eventlog = \(eventLogLevel);"
                _ = try await session.simpleQuery(sql)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Actions (Step Reordering)

    func reorderSteps(from source: IndexSet, to destination: Int) async {
        var reordered = steps
        reordered.move(fromOffsets: source, toOffset: destination)

        // Build mapping: old step_id -> new step_id (1-based position)
        let mapping: [(oldID: Int, newID: Int)] = reordered.enumerated().map { (index, step) in
            (oldID: step.id, newID: index + 1)
        }

        // If nothing changed, skip
        if mapping.allSatisfy({ $0.oldID == $0.newID }) { return }

        guard let jobID = selectedJobID else { return }

        // Optimistically update local state
        steps = reordered.enumerated().map { (index, step) in
            StepRow(id: index + 1, name: step.name, subsystem: step.subsystem, database: step.database, command: step.command)
        }

        do {
            // Build CASE expressions for remapping step references
            let caseParts = mapping.map { "WHEN \($0.oldID) THEN \($0.newID)" }.joined(separator: " ")
            let successCase = "CASE on_success_step_id \(caseParts) ELSE on_success_step_id END"
            let failCase = "CASE on_fail_step_id \(caseParts) ELSE on_fail_step_id END"

            // Individual step_id updates (using temp offset to avoid PK conflicts)
            let individualUpdates = mapping.map {
                "UPDATE msdb.dbo.sysjobsteps SET step_id = \($0.newID) WHERE job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))') AND step_id = \($0.oldID + 10000);"
            }.joined(separator: "\n")

            // Build start_step_id remap for the job itself
            let startStepCase = "CASE start_step_id \(caseParts) ELSE start_step_id END"

            let sql = """
            BEGIN TRANSACTION;

            UPDATE msdb.dbo.sysjobsteps
            SET on_success_step_id = \(successCase),
                on_fail_step_id = \(failCase)
            WHERE job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))');

            UPDATE msdb.dbo.sysjobsteps
            SET step_id = step_id + 10000
            WHERE job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))');

            \(individualUpdates)

            UPDATE msdb.dbo.sysjobs
            SET start_step_id = \(startStepCase)
            WHERE job_id = CONVERT(uniqueidentifier, N'\(escape(jobID))');

            COMMIT;
            """

            _ = try await session.simpleQuery(sql)
            // Reload from server so start_step_id and other references reflect the new order
            await loadDetails()
        } catch {
            errorMessage = error.localizedDescription
            // Reload from server on error
            await loadDetails()
        }
    }

    func detachSchedule(scheduleName: String) async {
        guard let jobName = selectedJobName() else { return }
        await performAction { agent in
            try await agent.detachSchedule(scheduleName: scheduleName, fromJob: jobName)
        }
        await loadDetails()
    }
}

// MARK: - Error

private enum AgentActionError: LocalizedError {
    case notMSSQL

    var errorDescription: String? {
        switch self {
        case .notMSSQL: return "Not connected to a SQL Server instance"
        }
    }
}
