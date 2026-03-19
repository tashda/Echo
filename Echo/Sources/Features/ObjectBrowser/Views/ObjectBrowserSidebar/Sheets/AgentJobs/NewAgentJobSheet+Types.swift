import SwiftUI
import SQLServerKit

// MARK: - Supporting Types

enum SubsystemChoice: String, CaseIterable {
    case tsql, cmdExec, powershell

    var builderSubsystem: SQLServerAgentJobStep.Subsystem {
        switch self {
        case .tsql: return .tsql
        case .cmdExec: return .cmdExec
        case .powershell: return .powershell
        }
    }
}

struct StepEntry: Identifiable {
    let id = UUID()
    var name: String
    var subsystem: SubsystemChoice = .tsql
    var database: String = ""
    var command: String = ""
}

enum ScheduleModeChoice: String, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case once = "One Time"
    var id: String { rawValue }
}

enum Weekday: Int, CaseIterable, Identifiable, Hashable {
    case sunday = 1, monday = 2, tuesday = 4, wednesday = 8, thursday = 16, friday = 32, saturday = 64

    var id: Int { rawValue }

    var shortName: String {
        switch self {
        case .sunday: "Sun"
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        }
    }

    /// Bitmask value for SQL Server's freq_interval
    var bitmask: Int { rawValue }
}

struct ScheduleEntry: Identifiable {
    let id = UUID()
    var name: String = ""
    var enabled: Bool = true
    var mode: ScheduleModeChoice = .daily
    var startHour: Int = 9
    var startMinute: Int = 0
    var intervalDays: Int = 1
    var intervalWeeks: Int = 1
    var intervalMonths: Int = 1
    var monthDay: Int = 1
    var weekdays: Set<Weekday> = [.monday]
    var oneTimeDate: Date = Date()

    var startTimeInt: Int { startHour * 10000 + startMinute * 100 }

    var weekdayBitmask: Int {
        weekdays.reduce(0) { $0 | $1.bitmask }
    }
}

enum NotifyLevelChoice: String, CaseIterable, Identifiable {
    case none = "None"
    case success = "On success"
    case failure = "On failure"
    case completion = "On completion"
    var id: String { rawValue }
}
