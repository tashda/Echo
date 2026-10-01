import Foundation
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Actions (Steps)

    /// Adds a step with what it does when it finishes (round 33.2, OC1).
    func addStep(name: String, subsystem: String, database: String?, command: String, proxyName: String? = nil,
                 outputFile: String? = nil, outcome: AgentJobStepOutcome = AgentJobStepOutcome()) async {
        guard let jobName = selectedJobName() else {
            errorMessage = "No job selected"
            return
        }
        let previousLastStep = steps.last
        await performAction { agent in
            try await agent.addStep(
                jobName: jobName,
                stepName: name,
                subsystem: subsystem,
                command: command,
                database: database,
                proxyName: proxyName,
                outputFile: outputFile
            )
            try await Self.configure(outcome, stepName: name, jobName: jobName, agent: agent)
            // The step that was last now goes on to the new one, so the job runs every step.
            if let previousLastStep {
                try await agent.configureStep(jobName: jobName, stepName: previousLastStep.name, onSuccessAction: 3)
            }
        }
        await loadDetails()
    }

    func updateStep(stepName: String, newCommand: String, database: String?, outcome: AgentJobStepOutcome? = nil) async {
        guard let jobName = selectedJobName() else { return }
        await performAction { agent in
            try await agent.updateTSQLStep(
                jobName: jobName,
                stepName: stepName,
                newCommand: newCommand,
                database: database
            )
            if let outcome {
                try await Self.configure(outcome, stepName: stepName, jobName: jobName, agent: agent)
            }
        }
        await loadDetails()
    }

    /// Checks a T-SQL step's command without running it (round 33.2, CE2). Nil when it parses.
    func parseCommand(_ command: String) async throws -> SQLServerParseIssue? {
        guard let mssql = session as? MSSQLSession else { return nil }
        return try await mssql.scripts.parse(command)
    }

    private static func configure(_ outcome: AgentJobStepOutcome, stepName: String, jobName: String, agent: SQLServerAgentOperations) async throws {
        try await agent.configureStep(
            jobName: jobName,
            stepName: stepName,
            onSuccessAction: outcome.onSuccess.action,
            onSuccessStepId: outcome.onSuccess.stepID,
            onFailAction: outcome.onFailure.action,
            onFailStepId: outcome.onFailure.stepID,
            retryAttempts: outcome.retryAttempts,
            retryIntervalMinutes: outcome.retryIntervalMinutes
        )
    }
}
