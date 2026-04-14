import Foundation
import Testing
@testable import Echo

/// Unit tests for SQL Agent supporting types (no database required).
struct AgentJobTypesTests {

    // MARK: - SubsystemChoice

    @Test
    func subsystemChoiceHasTwelveCases() {
        #expect(SubsystemChoice.allCases.count == 12)
    }

    @Test
    func subsystemChoiceReplicationDetection() {
        #expect(SubsystemChoice.snapshot.isReplicationSubsystem)
        #expect(SubsystemChoice.logReader.isReplicationSubsystem)
        #expect(SubsystemChoice.distribution.isReplicationSubsystem)
        #expect(SubsystemChoice.merge.isReplicationSubsystem)
        #expect(SubsystemChoice.queueReader.isReplicationSubsystem)
        #expect(!SubsystemChoice.tsql.isReplicationSubsystem)
        #expect(!SubsystemChoice.cmdExec.isReplicationSubsystem)
        #expect(!SubsystemChoice.powershell.isReplicationSubsystem)
        #expect(!SubsystemChoice.ssis.isReplicationSubsystem)
        #expect(!SubsystemChoice.analysisCommand.isReplicationSubsystem)
        #expect(!SubsystemChoice.analysisQuery.isReplicationSubsystem)
        #expect(!SubsystemChoice.activeScripting.isReplicationSubsystem)
    }

    @Test
    func subsystemChoiceBuilderMapping() {
        // Ensure every SubsystemChoice maps to a valid builder subsystem
        for choice in SubsystemChoice.allCases {
            let builder = choice.builderSubsystem
            #expect(!builder.rawValue.isEmpty, "Builder subsystem should have a raw value for \(choice)")
        }
    }

    // MARK: - ScheduleEntry

    @Test
    func scheduleEntryStartTimeIntFormat() {
        var entry = ScheduleEntry()
        entry.startHour = 14
        entry.startMinute = 30
        #expect(entry.startTimeInt == 143000, "14:30 should encode as 143000")
    }

    @Test
    func scheduleEntryWeekdayBitmask() {
        var entry = ScheduleEntry()
        entry.weekdays = [.monday, .wednesday, .friday]
        // Monday=2, Wednesday=8, Friday=32 → 42
        #expect(entry.weekdayBitmask == 42)
    }

    @Test
    func scheduleEntryActiveWindowDateWhenDisabled() {
        var entry = ScheduleEntry()
        entry.useActiveWindow = false
        #expect(entry.activeStartDateInt == nil, "Should be nil when active window disabled")
        #expect(entry.activeEndDateInt == nil, "Should be nil when active window disabled")
    }

    @Test
    func scheduleEntryActiveWindowDateWhenEnabled() {
        var entry = ScheduleEntry()
        entry.useActiveWindow = true
        // Dates are set to today and +1 year by default
        #expect(entry.activeStartDateInt != nil, "Should have a date when active window enabled")
        #expect(entry.activeEndDateInt != nil, "Should have a date when active window enabled")
    }

    // MARK: - ScheduleEditorResult

    @Test
    func scheduleEditorResultActiveTimeWhenDisabled() {
        let result = ScheduleEditorResult(
            name: "test", enabled: true, frequency: .daily,
            interval: 1, startHour: 9, startMinute: 0,
            weekdays: [], monthDay: 1, startDate: Date(),
            oneTimeDate: Date(), useActiveWindow: false,
            activeStartDate: Date(), activeEndDate: Date(),
            activeStartHour: 8, activeStartMinute: 0,
            activeEndHour: 18, activeEndMinute: 0
        )
        #expect(result.activeStartTimeInt == nil)
        #expect(result.activeEndTimeInt == nil)
    }

    @Test
    func scheduleEditorResultActiveTimeWhenEnabled() {
        let result = ScheduleEditorResult(
            name: "test", enabled: true, frequency: .daily,
            interval: 1, startHour: 9, startMinute: 0,
            weekdays: [], monthDay: 1, startDate: Date(),
            oneTimeDate: Date(), useActiveWindow: true,
            activeStartDate: Date(), activeEndDate: Date(),
            activeStartHour: 8, activeStartMinute: 30,
            activeEndHour: 18, activeEndMinute: 0
        )
        #expect(result.activeStartTimeInt == 83000, "8:30 should encode as 83000")
        #expect(result.activeEndTimeInt == 180000, "18:00 should encode as 180000")
    }

    // MARK: - ScheduleFrequency

    @Test
    func scheduleFrequencyTypes() {
        #expect(ScheduleFrequency.once.freqType == 1)
        #expect(ScheduleFrequency.daily.freqType == 4)
        #expect(ScheduleFrequency.weekly.freqType == 8)
        #expect(ScheduleFrequency.monthly.freqType == 16)
    }

    // MARK: - NotifyLevelChoice

    @Test
    func notifyLevelChoiceAllCases() {
        #expect(NotifyLevelChoice.allCases.count == 4)
        #expect(NotifyLevelChoice.none.rawValue == "None")
        #expect(NotifyLevelChoice.success.rawValue == "On success")
        #expect(NotifyLevelChoice.failure.rawValue == "On failure")
        #expect(NotifyLevelChoice.completion.rawValue == "On completion")
    }

    // MARK: - Weekday

    @Test
    func weekdayBitmaskValues() {
        #expect(Weekday.sunday.bitmask == 1)
        #expect(Weekday.monday.bitmask == 2)
        #expect(Weekday.tuesday.bitmask == 4)
        #expect(Weekday.wednesday.bitmask == 8)
        #expect(Weekday.thursday.bitmask == 16)
        #expect(Weekday.friday.bitmask == 32)
        #expect(Weekday.saturday.bitmask == 64)
    }

    @Test
    func weekdayShortNames() {
        #expect(Weekday.sunday.shortName == "Sun")
        #expect(Weekday.monday.shortName == "Mon")
        #expect(Weekday.saturday.shortName == "Sat")
    }

    // MARK: - ViewModel Row Types

    @Test
    func alertRowSortKey() {
        let enabled = JobQueueViewModel.AlertRow(id: "a", name: "A", severity: 17, messageId: nil, databaseName: nil, enabled: true)
        let disabled = JobQueueViewModel.AlertRow(id: "b", name: "B", severity: 17, messageId: nil, databaseName: nil, enabled: false)
        #expect(enabled.enabledSortKey == "1")
        #expect(disabled.enabledSortKey == "0")
    }

    @Test
    func proxyRowSortKey() {
        let enabled = JobQueueViewModel.ProxyRow(id: "a", name: "A", credentialName: "cred", enabled: true)
        let disabled = JobQueueViewModel.ProxyRow(id: "b", name: "B", credentialName: nil, enabled: false)
        #expect(enabled.enabledSortKey == "1")
        #expect(disabled.enabledSortKey == "0")
    }
}
