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
