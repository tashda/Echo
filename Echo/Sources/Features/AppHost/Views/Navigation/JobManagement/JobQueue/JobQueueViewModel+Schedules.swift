import Foundation
import SQLServerKit

extension JobQueueViewModel {

    // MARK: - Actions (Schedules)

    /// Edit Schedule (the owner, 2026-10-01). The schedule changes in place, so every job it is
    /// attached to follows; a new name renames it.
    func updateSchedule(originalName: String, name: String, enabled: Bool, fields: AgentJobScheduleFields) async {
        await performAction { agent in
            try await agent.updateSchedule(
                name: originalName,
                newName: name == originalName ? nil : name,
                enabled: enabled,
                freqType: fields.freqType,
                freqInterval: fields.freqInterval,
                activeStartDate: fields.activeStartDate,
                activeStartTime: fields.activeStartTime,
                activeEndDate: fields.activeEndDate,
                freqRecurrenceFactor: fields.freqRecurrenceFactor
            )
        }
        await loadDetails()
    }
}
