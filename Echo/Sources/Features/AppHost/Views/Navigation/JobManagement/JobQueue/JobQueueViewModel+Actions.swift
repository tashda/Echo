import Foundation
import SwiftUI
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Agent Client

    func withAgentClient<T>(_ body: (SQLServerAgentOperations) async throws -> T) async throws -> T {
        guard let mssql = session as? MSSQLSession else {
            throw AgentActionError.notMSSQL
        }
        let agent = mssql.agent
        return try await body(agent)
    }

    private func performAction(_ action: @escaping (SQLServerAgentOperations) async throws -> Void) async {
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
        manuallyStartedJobName = jobName
        manualStartHandle?.cancel()
        manualStartHandle = activityEngine?.begin("Running: \(jobName)", connectionSessionID: connectionSessionID)
        jobStartedAt = Date()
        jobSeenRunning = false
        runningJobNames.insert(jobName)
        activeStepInfo = ActiveStepInfo(jobName: jobName, stepID: 0, stepName: "Starting\u{2026}", startTime: Date())

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
        manuallyStartedJobName = nil
        manualStartHandle?.succeed()
        manualStartHandle = nil
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
                try await agent.configureStep(
                    jobName: jobName,
                    stepName: lastStep.name,
                    onSuccessAction: 3  // Go to next step
                )
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
            try await agent.updateJob(named: jobName, notifyLevelEventlog: eventLogLevel)
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

        guard let jobName = selectedJobName() else { return }

        // Optimistically update local state
        steps = reordered.enumerated().map { (index, step) in
            StepRow(id: index + 1, name: step.name, subsystem: step.subsystem, database: step.database, command: step.command)
        }

        await performAction { agent in
            try await agent.reorderJobSteps(jobName: jobName, stepMapping: mapping)
        }
        await loadDetails()
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
