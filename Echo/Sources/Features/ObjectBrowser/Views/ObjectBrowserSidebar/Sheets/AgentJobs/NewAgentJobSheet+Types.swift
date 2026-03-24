import SwiftUI
import SQLServerKit

// MARK: - Supporting Types

enum SubsystemChoice: String, CaseIterable, Identifiable {
    case tsql = "T-SQL"
    case cmdExec = "CmdExec"
    case powershell = "PowerShell"
    case ssis = "SSIS Package"
    case snapshot = "Snapshot Agent"
    case logReader = "Log Reader Agent"
    case distribution = "Distribution Agent"
    case merge = "Merge Agent"
    case queueReader = "Queue Reader Agent"
    case analysisCommand = "Analysis Services Command"
    case analysisQuery = "Analysis Services Query"
    case activeScripting = "ActiveScripting"

    var id: String { rawValue }

    var builderSubsystem: SQLServerAgentJobStep.Subsystem {
        switch self {
        case .tsql: return .tsql
        case .cmdExec: return .cmdExec
        case .powershell: return .powershell
        case .ssis: return .ssis
        case .snapshot: return .snapshot
        case .logReader: return .logReader
        case .distribution: return .distribution
        case .merge: return .merge
        case .queueReader: return .queueReader
        case .analysisCommand: return .analysisCommand
        case .analysisQuery: return .analysisQuery
        case .activeScripting: return .activeScripting
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
    var useActiveWindow: Bool = false
    var activeStartDate: Date = Date()
    var activeEndDate: Date = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    var startTimeInt: Int { startHour * 10000 + startMinute * 100 }

    var weekdayBitmask: Int {
        weekdays.reduce(0) { $0 | $1.bitmask }
    }

    var activeStartDateInt: Int? {
        guard useActiveWindow else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: activeStartDate)
        return (comps.year ?? 2026) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    }

    var activeEndDateInt: Int? {
        guard useActiveWindow else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: activeEndDate)
        return (comps.year ?? 2027) * 10000 + (comps.month ?? 1) * 100 + (comps.day ?? 1)
    }
}

enum NotifyLevelChoice: String, CaseIterable, Identifiable {
    case none = "None"
    case success = "On success"
    case failure = "On failure"
    case completion = "On completion"
    var id: String { rawValue }
}
