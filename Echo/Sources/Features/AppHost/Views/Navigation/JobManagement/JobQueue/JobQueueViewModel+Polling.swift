import Foundation
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Job Activity Polling

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
                isJobRunning = true
            } else {
                isJobRunning = false
            }

            var runningNames = Set(running.map { $0.name })
            if inGracePeriod, let jobName {
                runningNames.insert(jobName)
            }
            self.runningJobNames = runningNames

            // While running, query current step activity via typed API
            if isJobRunning, let jobName {
                if !inGracePeriod {
                    await loadActiveStepInfo(jobName: jobName)
                }
                await loadHistory(all: false)
            } else if !polledRunning {
                activeStepInfo = nil
            }

            // Clear manually-started tracking when that specific job is no longer running
            if let startedName = manuallyStartedJobName, !runningNames.contains(startedName) {
                let lastOutcome = history.first(where: { $0.jobName == startedName && $0.stepId == 0 })?.status
                let succeeded = lastOutcome == 1
                if succeeded {
                    notificationEngine?.post(.jobCompleted(name: startedName))
                    manualStartHandle?.succeed()
                } else {
                    notificationEngine?.post(.jobFailed(name: startedName))
                    manualStartHandle?.fail(startedName)
                }
                manuallyStartedJobName = nil
                manualStartHandle = nil
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

    // MARK: - Active Step (typed API)

    func loadActiveStepInfo(jobName: String) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let agent = mssql.agent
            if let step = try await agent.getActiveJobStep(jobName: jobName) {
                activeStepInfo = ActiveStepInfo(
                    jobName: step.jobName,
                    stepID: step.lastExecutedStepId,
                    stepName: step.stepName ?? "Step \(step.lastExecutedStepId)",
                    startTime: step.startExecutionDate ?? Date()
                )
            } else {
                activeStepInfo = nil
            }
        } catch {
            // Non-critical — don't surface errors for activity polling
        }
    }
}
