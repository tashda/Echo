import Foundation

/// A schedule as SQL Agent stores it, from the schedule sheet's fields and back, so New Schedule and
/// Edit Schedule write the same values (the owner, 2026-10-01: schedules can be edited).
struct AgentJobScheduleFields: Equatable {
    var freqType: Int
    var freqInterval: Int
    var freqRecurrenceFactor: Int?
    var activeStartDate: Int?
    var activeStartTime: Int
    var activeEndDate: Int?

    /// SQL Agent's "no end date".
    static let noEndDate = 99_991_231

    init(result: ScheduleEditorResult, calendar: Calendar = .current) {
        activeStartTime = result.startHour * 10_000 + result.startMinute * 100
        freqRecurrenceFactor = nil
        activeStartDate = nil
        activeEndDate = nil
        switch result.frequency {
        case .daily:
            freqType = 4; freqInterval = result.interval
        case .weekly:
            freqType = 8; freqInterval = result.weekdays.reduce(0, |); freqRecurrenceFactor = result.interval
        case .monthly:
            freqType = 16; freqInterval = result.monthDay; freqRecurrenceFactor = result.interval
        case .once:
            freqType = 1; freqInterval = 0
            activeStartDate = Self.agentDate(result.oneTimeDate, calendar: calendar)
        }
        if result.frequency != .once {
            // Without an active window the schedule runs with no end; an edit that turns the window
            // off must clear the end date it had.
            activeStartDate = result.useActiveWindow ? Self.agentDate(result.activeStartDate, calendar: calendar) : nil
            activeEndDate = result.useActiveWindow ? Self.agentDate(result.activeEndDate, calendar: calendar) : Self.noEndDate
        }
    }

    static func agentDate(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 2026) * 10_000 + (parts.month ?? 1) * 100 + (parts.day ?? 1)
    }

    static func date(agentDate: Int?, calendar: Calendar) -> Date? {
        guard let agentDate, agentDate > 0, agentDate < noEndDate else { return nil }
        return calendar.date(from: DateComponents(year: agentDate / 10_000, month: (agentDate / 100) % 100, day: agentDate % 100))
    }
}

/// What the schedule sheet opens on when it edits an existing schedule.
struct ScheduleEditorInitialValues {
    var name = ""
    var enabled = true
    var frequency: ScheduleFrequency = .daily
    var interval = 1
    var startHour = 9
    var startMinute = 0
    var weekdays: Set<Int> = [2]
    var monthDay = 1
    var oneTimeDate = Date()
    var useActiveWindow = false
    var activeStartDate = Date()
    var activeEndDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    init() {}

    /// Nil for the kinds the sheet can't show (monthly relative, when Agent starts, when idle).
    init?(schedule: JobQueueViewModel.ScheduleRow, calendar: Calendar = .current) {
        guard let frequency = ScheduleFrequency(freqType: schedule.freqType) else { return nil }
        name = schedule.name
        enabled = schedule.enabled
        self.frequency = frequency
        let time = schedule.activeStartTime ?? 0
        startHour = time / 10_000
        startMinute = (time / 100) % 100
        switch frequency {
        case .daily:
            interval = max(schedule.freqInterval, 1)
        case .weekly:
            interval = max(schedule.freqRecurrenceFactor ?? 1, 1)
            weekdays = Set([1, 2, 4, 8, 16, 32, 64].filter { schedule.freqInterval & $0 != 0 })
        case .monthly:
            interval = max(schedule.freqRecurrenceFactor ?? 1, 1)
            monthDay = min(max(schedule.freqInterval, 1), 31)
        case .once:
            oneTimeDate = AgentJobScheduleFields.date(agentDate: schedule.activeStartDate, calendar: calendar) ?? Date()
        }
        if frequency != .once, let end = AgentJobScheduleFields.date(agentDate: schedule.activeEndDate, calendar: calendar) {
            useActiveWindow = true
            activeEndDate = end
            activeStartDate = AgentJobScheduleFields.date(agentDate: schedule.activeStartDate, calendar: calendar) ?? Date()
        }
    }
}

extension ScheduleFrequency {
    init?(freqType: Int) {
        guard let match = Self.allCases.first(where: { $0.freqType == freqType }) else { return nil }
        self = match
    }
}
