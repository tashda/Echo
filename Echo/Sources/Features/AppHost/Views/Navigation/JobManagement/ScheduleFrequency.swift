import Foundation

enum ScheduleFrequency: String, CaseIterable, Identifiable {
    case once = "once"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .once: return "One Time"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var freqType: Int {
        switch self {
        case .once: return 1
        case .daily: return 4
        case .weekly: return 8
        case .monthly: return 16
        }
    }
}

/// Result from the schedule editor sheet, capturing all form fields.
struct ScheduleEditorResult {
    let name: String
    let enabled: Bool
    let frequency: ScheduleFrequency
    let interval: Int
    let startHour: Int
    let startMinute: Int
    let weekdays: Set<Int>
    let monthDay: Int
    let startDate: Date
    let oneTimeDate: Date
    let useActiveWindow: Bool
    let activeStartDate: Date
    let activeEndDate: Date
    let activeStartHour: Int
    let activeStartMinute: Int
    let activeEndHour: Int
    let activeEndMinute: Int

    var activeStartTimeInt: Int? {
        guard useActiveWindow else { return nil }
        return activeStartHour * 10000 + activeStartMinute * 100
    }

    var activeEndTimeInt: Int? {
        guard useActiveWindow else { return nil }
        return activeEndHour * 10000 + activeEndMinute * 100
    }
}
