import Foundation

/// Defines every notification type that flows through ``NotificationEngine``.
///
/// Each category carries a default icon, toast style, and human-readable
/// display name so call sites can post with minimal boilerplate.
enum NotificationCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    // Connection
    case connectionConnected
    case connectionDisconnected
    case connectionFailed

    // Object Browser
    case objectDropped
    case objectRenamed
    case objectCreated
    case objectTruncated

    // Extensions
    case extensionInstalled
    case extensionFailed

    // Maintenance
    case maintenanceCompleted
    case maintenanceFailed

    // Security
    case securityDropped
    case securityToggleFailed

    // Table Structure
    case tableStructureUpdated
    case indexCreated
    case indexDropped
    case indexRebuilt
    case indexRebuildFailed

    // Database
    case databaseCreated
    case databaseCreationFailed
    case databaseSwitched
    case databaseSwitchFailed
    case databasePropertiesError
    case databasePropertiesSaved

    // Jobs
    case jobStarted
    case jobStopped
    case jobError
    case jobScheduleCreated
    case jobNotificationSaved
    case jobPropertiesSaved

    // General
    case generalSuccess
    case generalError
    case generalInfo

    var id: String { rawValue }

    var group: NotificationGroup {
        switch self {
        case .connectionConnected, .connectionDisconnected, .connectionFailed:
            return .connection
        case .objectDropped, .objectRenamed, .objectCreated, .objectTruncated,
             .extensionInstalled, .extensionFailed,
             .maintenanceCompleted, .maintenanceFailed,
             .securityDropped, .securityToggleFailed:
            return .objectBrowser
        case .tableStructureUpdated, .indexCreated, .indexDropped, .indexRebuilt, .indexRebuildFailed:
            return .tableStructure
        case .databaseCreated, .databaseCreationFailed,
             .databaseSwitched, .databaseSwitchFailed, .databasePropertiesError, .databasePropertiesSaved:
            return .database
        case .jobStarted, .jobStopped, .jobError, .jobScheduleCreated, .jobNotificationSaved, .jobPropertiesSaved:
            return .jobs
        case .generalSuccess, .generalError, .generalInfo:
            return .general
        }
    }

    var displayName: String {
        switch self {
        case .connectionConnected: return "Connected"
        case .connectionDisconnected: return "Disconnected"
        case .connectionFailed: return "Connection Failed"
        case .objectDropped: return "Object Dropped"
        case .objectRenamed: return "Object Renamed"
        case .objectCreated: return "Object Created"
        case .objectTruncated: return "Object Truncated"
        case .extensionInstalled: return "Extension Installed"
        case .extensionFailed: return "Extension Failed"
        case .maintenanceCompleted: return "Maintenance Completed"
        case .maintenanceFailed: return "Maintenance Failed"
        case .securityDropped: return "Security Object Dropped"
        case .securityToggleFailed: return "Security Toggle Failed"
        case .tableStructureUpdated: return "Structure Updated"
        case .indexCreated: return "Index Created"
        case .indexDropped: return "Index Dropped"
        case .indexRebuilt: return "Index Rebuilt"
        case .indexRebuildFailed: return "Index Rebuild Failed"
        case .databaseCreated: return "Database Created"
        case .databaseCreationFailed: return "Database Creation Failed"
        case .databaseSwitched: return "Database Switched"
        case .databaseSwitchFailed: return "Database Switch Failed"
        case .databasePropertiesError: return "Properties Error"
        case .databasePropertiesSaved: return "Properties Saved"
        case .jobStarted: return "Job Started"
        case .jobStopped: return "Job Stopped"
        case .jobError: return "Job Error"
        case .jobScheduleCreated: return "Schedule Created"
        case .jobNotificationSaved: return "Notification Saved"
        case .jobPropertiesSaved: return "Properties Saved"
        case .generalSuccess: return "Success"
        case .generalError: return "Error"
        case .generalInfo: return "Info"
        }
    }

    var defaultIcon: String {
        switch self {
        case .connectionConnected: return "checkmark.circle.fill"
        case .connectionDisconnected: return "bolt.horizontal.circle"
        case .connectionFailed: return "exclamationmark.triangle.fill"
        case .objectDropped: return "checkmark.circle"
        case .objectRenamed: return "checkmark.circle"
        case .objectCreated: return "checkmark.circle"
        case .objectTruncated: return "checkmark.circle"
        case .extensionInstalled: return "puzzlepiece.fill"
        case .extensionFailed: return "exclamationmark.triangle"
        case .maintenanceCompleted: return "checkmark.circle"
        case .maintenanceFailed: return "exclamationmark.triangle"
        case .securityDropped: return "checkmark.circle"
        case .securityToggleFailed: return "exclamationmark.triangle"
        case .tableStructureUpdated: return "checkmark.circle"
        case .indexCreated: return "checkmark.circle"
        case .indexDropped: return "checkmark.circle"
        case .indexRebuilt: return "checkmark.circle"
        case .indexRebuildFailed: return "exclamationmark.triangle"
        case .databaseCreated: return "checkmark.circle.fill"
        case .databaseCreationFailed: return "exclamationmark.triangle.fill"
        case .databaseSwitched: return "arrow.triangle.swap"
        case .databaseSwitchFailed: return "exclamationmark.triangle.fill"
        case .databasePropertiesError: return "exclamationmark.triangle"
        case .databasePropertiesSaved: return "checkmark.circle.fill"
        case .jobStarted: return "play.fill"
        case .jobStopped: return "stop.fill"
        case .jobError: return "exclamationmark.triangle.fill"
        case .jobScheduleCreated: return "calendar.badge.plus"
        case .jobNotificationSaved: return "bell.fill"
        case .jobPropertiesSaved: return "checkmark.circle.fill"
        case .generalSuccess: return "checkmark.circle.fill"
        case .generalError: return "exclamationmark.triangle.fill"
        case .generalInfo: return "info.circle"
        }
    }

    var defaultStyle: StatusToastView.StatusToastStyle {
        switch self {
        case .connectionConnected, .objectDropped, .objectRenamed, .objectCreated, .objectTruncated,
             .extensionInstalled, .maintenanceCompleted, .securityDropped,
             .tableStructureUpdated, .indexCreated, .indexDropped, .indexRebuilt,
             .jobStarted, .jobStopped, .jobScheduleCreated, .jobNotificationSaved, .jobPropertiesSaved,
             .databaseCreated, .databasePropertiesSaved, .generalSuccess:
            return .success
        case .connectionFailed, .extensionFailed, .maintenanceFailed, .securityToggleFailed,
             .indexRebuildFailed, .databaseCreationFailed, .databaseSwitchFailed, .databasePropertiesError,
             .jobError, .generalError:
            return .error
        case .connectionDisconnected, .databaseSwitched, .generalInfo:
            return .info
        }
    }
}

/// Groups categories for the Settings UI.
enum NotificationGroup: String, CaseIterable, Identifiable, Sendable {
    case connection
    case objectBrowser
    case tableStructure
    case database
    case jobs
    case general

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .connection: return "Connection"
        case .objectBrowser: return "Object Browser"
        case .tableStructure: return "Table Structure"
        case .database: return "Database"
        case .jobs: return "Jobs"
        case .general: return "General"
        }
    }

    var systemImage: String {
        switch self {
        case .connection: return "bolt.horizontal.circle"
        case .objectBrowser: return "list.bullet.indent"
        case .tableStructure: return "tablecells"
        case .database: return "externaldrive"
        case .jobs: return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .general: return "bell"
        }
    }

    var categories: [NotificationCategory] {
        NotificationCategory.allCases.filter { $0.group == self }
    }
}
