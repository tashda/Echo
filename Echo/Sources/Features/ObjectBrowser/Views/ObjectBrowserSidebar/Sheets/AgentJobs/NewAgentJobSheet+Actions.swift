import SwiftUI
import SQLServerKit

extension NewAgentJobSheet {

    // MARK: - Actions

    func loadCurrentLogin() {
        guard jobOwner.isEmpty else { return }
        Task {
            do {
                let rs = try await session.session.simpleQuery("SELECT SUSER_SNAME() AS name;")
                let val = rs.rows.first?[0] ?? ""
                await MainActor.run { jobOwner = val }
            } catch { }
        }
    }

    func createJob() async {
        let name = jobName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Job name is required"
            return
        }
        guard let mssql = session.session as? MSSQLSession else {
            errorMessage = "Not connected to a SQL Server instance"
            return
        }

        isCreating = true
        errorMessage = nil

        do {
            let agent = mssql.agent
            let builder = SQLServerAgentJobBuilder(
                agent: agent,
                jobName: name,
                description: jobDescription.isEmpty ? nil : jobDescription,
                enabled: jobEnabled,
                ownerLoginName: jobOwner.isEmpty ? nil : jobOwner,
                categoryName: jobCategory.isEmpty ? nil : jobCategory,
                autoAttachServer: true
            )

            // Add steps
            for step in steps {
                let s = SQLServerAgentJobStep(
                    name: step.name,
                    subsystem: step.subsystem.builderSubsystem,
                    command: step.command,
                    database: step.database.isEmpty ? nil : step.database
                )
                _ = builder.addStep(s)
            }

            if steps.count > 1 {
                _ = builder.setStartStepId(startStepId)
            }

            // Add schedules
            for schedule in schedules {
                let startTimeInt = schedule.startTimeInt
                let kind: SQLServerAgentJobSchedule.Kind
                switch schedule.mode {
                case .daily:
                    kind = .daily(everyDays: max(1, schedule.intervalDays), startTime: startTimeInt)
                case .weekly:
                    let days: [SQLServerAgentJobSchedule.WeeklyDay] = Weekday.allCases
                        .filter { schedule.weekdays.contains($0) }
                        .compactMap { day -> SQLServerAgentJobSchedule.WeeklyDay? in
                            switch day {
                            case .sunday: return .sunday
                            case .monday: return .monday
                            case .tuesday: return .tuesday
                            case .wednesday: return .wednesday
                            case .thursday: return .thursday
                            case .friday: return .friday
                            case .saturday: return .saturday
                            }
                        }
                    kind = .weekly(days: days.isEmpty ? [.monday] : days, everyWeeks: schedule.intervalWeeks, startTime: startTimeInt)
                case .monthly:
                    kind = .monthly(day: schedule.monthDay, everyMonths: schedule.intervalMonths, startTime: startTimeInt)
                case .once:
                    let comps = Calendar.current.dateComponents([.year, .month, .day], from: schedule.oneTimeDate)
                    let dateInt = (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
                    kind = .oneTime(startDate: dateInt, startTime: startTimeInt)
                }

                let scheduleName = schedule.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let sch = SQLServerAgentJobSchedule(
                    name: scheduleName.isEmpty ? "Schedule_\(name)" : scheduleName,
                    enabled: schedule.enabled,
                    kind: kind
                )
                _ = builder.addSchedule(sch)
            }

            // Notification
            if !notifyOperator.isEmpty && notifyLevel != .none {
                let level: SQLServerAgentJobNotification.Level
                switch notifyLevel {
                case .none: level = .none
                case .success: level = .onSuccess
                case .failure: level = .onFailure
                case .completion: level = .onCompletion
                }
                _ = builder.setNotification(SQLServerAgentJobNotification(
                    operatorName: notifyOperator,
                    level: level
                ))
            }

            let (_, jobId) = try await builder.commit()

            if startAfterCreate {
                _ = try? await agent.startJob(named: name)
            }

            await MainActor.run {
                isCreating = false
                environmentState.openJobQueueTab(for: session, selectJobID: jobId)
                onComplete()
            }
        } catch {
            await MainActor.run {
                isCreating = false
                errorMessage = error.localizedDescription
            }
        }
    }
}
