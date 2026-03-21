import Foundation
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Load Details (typed APIs)

    func loadDetails() async {
        guard let jobName = jobs.first(where: { $0.id == selectedJobID })?.name else {
            properties = nil; steps = []; schedules = []; return
        }
        guard let mssql = session as? MSSQLSession else { return }
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            let agent = mssql.agent

            // Properties from getJobDetail
            if let detail = try await agent.getJobDetail(jobName: jobName) {
                self.properties = PropertySheet(
                    name: detail.name,
                    description: detail.description,
                    owner: detail.ownerLoginName,
                    category: detail.categoryName,
                    enabled: detail.enabled,
                    startStepId: detail.startStepId,
                    notifyLevelEmail: detail.notifyLevelEmail,
                    notifyEmailOperator: detail.notifyEmailOperatorName,
                    notifyLevelEventlog: detail.notifyLevelEventlog
                )
            } else {
                self.properties = nil
            }

            // Steps
            let stepTuples = try await agent.listSteps(jobName: jobName)
            self.steps = stepTuples.map { step in
                StepRow(id: step.id, name: step.name, subsystem: step.subsystem, database: step.database, command: step.command)
            }

            // Schedules
            let scheduleDetails = try await agent.getJobSchedules(jobName: jobName)
            self.schedules = scheduleDetails.map { sch in
                let nextRunStr = sch.nextRunDate.map { Self.formatDate($0) }
                return ScheduleRow(
                    id: sch.scheduleId,
                    name: sch.name,
                    enabled: sch.enabled,
                    freqType: sch.freqType,
                    freqInterval: sch.freqInterval ?? 0,
                    next: nextRunStr
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Load History (typed API)

    func loadHistory(all: Bool) async {
        guard let mssql = session as? MSSQLSession else { return }
        do {
            let agent = mssql.agent
            let jobName: String?
            if !all, let id = selectedJobID, !id.isEmpty {
                jobName = jobs.first(where: { $0.id == id })?.name
            } else {
                jobName = nil
            }

            let entries = try await agent.getJobHistory(jobName: jobName, top: 200)
            self.history = entries.enumerated().map { index, entry in
                // Convert runDateTime back to YYYYMMDD/HHMMSS ints for the existing HistoryRow format
                let (runDate, runTime) = Self.dateToAgentInts(entry.runDateTime)
                let durationSeconds = entry.runDurationSeconds ?? 0
                // Convert seconds back to HHMMSS format for display
                let durationHHMMSS = (durationSeconds / 3600) * 10000 + ((durationSeconds % 3600) / 60) * 100 + (durationSeconds % 60)

                return HistoryRow(
                    id: entry.instanceId,
                    jobName: entry.jobName,
                    stepId: entry.stepId,
                    stepName: entry.stepName ?? "Step \(entry.stepId)",
                    status: entry.runStatus,
                    message: entry.message,
                    runDate: runDate,
                    runTime: runTime,
                    runDuration: durationHHMMSS
                )
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    /// Convert a Date back to SQL Server agent integer format (YYYYMMDD, HHMMSS).
    private static func dateToAgentInts(_ date: Date?) -> (Int, Int) {
        guard let date else { return (0, 0) }
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let dateInt = (comps.year ?? 0) * 10000 + (comps.month ?? 0) * 100 + (comps.day ?? 0)
        let timeInt = (comps.hour ?? 0) * 10000 + (comps.minute ?? 0) * 100 + (comps.second ?? 0)
        return (dateInt, timeInt)
    }
}
