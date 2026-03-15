import Foundation

/// How notifications are delivered to the user.
enum NotificationDelivery: String, Codable, Hashable, CaseIterable, Sendable {
    case inApp
    case native
    case both

    var displayName: String {
        switch self {
        case .inApp: return "In-App Toast"
        case .native: return "Native macOS"
        case .both: return "Both"
        }
    }
}

/// User-configurable notification settings, persisted in ``GlobalSettings``.
struct NotificationPreferences: Codable, Hashable, Sendable {
    var delivery: NotificationDelivery = .inApp
    var disabledCategories: Set<String> = []

    func isEnabled(_ category: NotificationCategory) -> Bool {
        !disabledCategories.contains(category.rawValue)
    }

    mutating func setEnabled(_ enabled: Bool, for category: NotificationCategory) {
        if enabled {
            disabledCategories.remove(category.rawValue)
        } else {
            disabledCategories.insert(category.rawValue)
        }
    }
}
