import Foundation
import Testing
@testable import Echo

/// New Schedule and Edit Schedule write the same SQL Agent values, and Edit opens on what is stored.
@MainActor
struct AgentJobScheduleFieldsTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
    }

    private func result(_ frequency: ScheduleFrequency, interval: Int = 1, weekdays: Set<Int> = [2], monthDay: Int = 1,
                        window: Bool = false) -> ScheduleEditorResult {
        ScheduleEditorResult(name: "Nightly", enabled: true, frequency: frequency, interval: interval, startHour: 23, startMinute: 17,
                             weekdays: weekdays, monthDay: monthDay, startDate: date(2026, 1, 1), oneTimeDate: date(2026, 10, 5),
                             useActiveWindow: window, activeStartDate: date(2026, 1, 1), activeEndDate: date(2026, 12, 31),
                             activeStartHour: 0, activeStartMinute: 0, activeEndHour: 23, activeEndMinute: 59)
    }

    @Test func weeklyOnMondayAndWednesdayEveryOtherWeek() {
        let fields = AgentJobScheduleFields(result: result(.weekly, interval: 2, weekdays: [2, 8]), calendar: calendar)
        #expect(fields.freqType == 8)
        #expect(fields.freqInterval == 10)
        #expect(fields.freqRecurrenceFactor == 2)
        #expect(fields.activeStartTime == 231_700)
        #expect(fields.activeEndDate == AgentJobScheduleFields.noEndDate)
    }

    @Test func aWindowSetsBothDatesAndOnceSetsItsDay() {
        let windowed = AgentJobScheduleFields(result: result(.daily, interval: 3, window: true), calendar: calendar)
        #expect(windowed.freqType == 4 && windowed.freqInterval == 3)
        #expect(windowed.activeStartDate == 20_260_101 && windowed.activeEndDate == 20_261_231)
        let once = AgentJobScheduleFields(result: result(.once), calendar: calendar)
        #expect(once.freqType == 1 && once.activeStartDate == 20_261_005 && once.activeEndDate == nil)
    }

    @Test func editOpensOnTheStoredSchedule() throws {
        let row = JobQueueViewModel.ScheduleRow(id: "7", name: "Nightly", enabled: false, freqType: 8, freqInterval: 10, next: nil,
                                                freqRecurrenceFactor: 2, activeStartDate: 20_260_101, activeStartTime: 231_700,
                                                activeEndDate: 20_261_231)
        let initial = try #require(ScheduleEditorInitialValues(schedule: row, calendar: calendar))
        #expect(initial.frequency == .weekly && initial.interval == 2 && initial.weekdays == [2, 8])
        #expect(initial.startHour == 23 && initial.startMinute == 17 && !initial.enabled)
        #expect(initial.useActiveWindow && initial.activeEndDate == date(2026, 12, 31))
    }

    @Test func noEndDateMeansNoWindowAndUnknownKindsAreNotEditable() {
        let open = JobQueueViewModel.ScheduleRow(id: "1", name: "Daily", enabled: true, freqType: 4, freqInterval: 1, next: nil,
                                                 activeStartDate: 20_260_101, activeStartTime: 90_000,
                                                 activeEndDate: AgentJobScheduleFields.noEndDate)
        #expect(ScheduleEditorInitialValues(schedule: open, calendar: calendar)?.useActiveWindow == false)
        let relative = JobQueueViewModel.ScheduleRow(id: "2", name: "Last Friday", enabled: true, freqType: 32, freqInterval: 6, next: nil)
        #expect(ScheduleEditorInitialValues(schedule: relative) == nil)
    }
}
