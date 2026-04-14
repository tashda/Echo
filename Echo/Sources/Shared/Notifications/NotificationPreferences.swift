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

    var displayDescription: String {
        switch self {
        case .inApp: return "Show banners inside Echo"
        case .native: return "Show macOS Notification Center banners"
        case .both: return "Show both in-app and macOS banners"
        }
    }
}

/// User-configurable notification settings, persisted in ``GlobalSettings``.
struct NotificationPreferences: Codable, Hashable, Sendable {
    var delivery: NotificationDelivery = .inApp
    var disabledCategories: Set<String> = []

    /// Whether a specific category is enabled.
    /// On first launch (empty `disabledCategories` and no stored defaults),
    /// only critical categories (errors and failures) are enabled.
    func isEnabled(_ category: NotificationCategory) -> Bool {
        if hasExplicitPreferences {
            return !disabledCategories.contains(category.rawValue)
        }
        // Fresh install: only critical categories are on by default
        return category.isCriticalDefault
    }

    mutating func setEnabled(_ enabled: Bool, for category: NotificationCategory) {
        if enabled {
            disabledCategories.remove(category.rawValue)
        } else {
            disabledCategories.insert(category.rawValue)
        }
    }

    /// Whether the user has explicitly toggled any category.
    /// When false, the system uses the critical-defaults policy.
    private var hasExplicitPreferences: Bool {
        // If the disabled set is non-empty, the user has made choices.
        // We also check for a sentinel key written on first explicit toggle.
        return disabledCategories.contains(hasExplicitPreferencesKey)
            || disabledCategories.contains(allEnabledSentinelKey)
    }

    /// Mark that the user has explicitly chosen their preferences.
    mutating func markExplicitPreferences() {
        // Ensure the preferences are recognized as explicit going forward
        if !hasExplicitPreferences {
            disabledCategories.insert(hasExplicitPreferencesKey)
        }
    }

    /// Enable all notification categories.
    mutating func enableAll() {
        disabledCategories = [hasExplicitPreferencesKey]
    }

    /// Disable all notification categories.
    mutating func disableAll() {
        var all = Set(NotificationCategory.allCases.map(\.rawValue))
        all.insert(hasExplicitPreferencesKey)
        disabledCategories = all
    }

    /// Whether all categories are enabled (given explicit preferences).
    var isAllEnabled: Bool {
        guard hasExplicitPreferences else { return false }
        return disabledCategories.subtracting([hasExplicitPreferencesKey, allEnabledSentinelKey]).isEmpty
    }

    /// Whether a whole group has any enabled notifications.
    func isGroupEnabled(_ group: NotificationGroup) -> Bool {
        group.categories.contains { isEnabled($0) }
    }

    /// Enable or disable an entire group at once.
    mutating func setGroupEnabled(_ enabled: Bool, for group: NotificationGroup) {
        markExplicitPreferences()
        for category in group.categories {
            setEnabled(enabled, for: category)
        }
    }

    // Sentinel keys for tracking explicit user preferences
    private var hasExplicitPreferencesKey: String { "__explicit" }
    private var allEnabledSentinelKey: String { "__allEnabled" }
}
