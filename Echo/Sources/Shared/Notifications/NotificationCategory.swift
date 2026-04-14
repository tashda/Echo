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

    // MARK: - Critical Default

    /// Whether this category is enabled by default on first launch.
    /// Only error and failure notifications are considered critical.
    var isCriticalDefault: Bool {
        switch self {
        case .connectionFailed,
             .extensionFailed,
             .maintenanceFailed,
             .securityToggleFailed,
             .indexRebuildFailed,
             .databaseCreationFailed,
             .databaseSwitchFailed,
             .databasePropertiesError,
             .jobError,
             .generalError:
            return true
        default:
            return false
        }
    }

    // MARK: - Group

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

    // MARK: - Display

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

    var displayDescription: String {
        switch self {
        case .connectionConnected: return "When a database connection is established"
        case .connectionDisconnected: return "When a connection is closed or drops"
        case .connectionFailed: return "When a connection attempt fails"
        case .objectDropped: return "When a database object is deleted"
        case .objectRenamed: return "When a database object is renamed"
        case .objectCreated: return "When a new database object is created"
        case .objectTruncated: return "When a table is truncated"
        case .extensionInstalled: return "When a PostgreSQL extension is installed"
        case .extensionFailed: return "When an extension operation fails"
        case .maintenanceCompleted: return "When a maintenance task finishes"
        case .maintenanceFailed: return "When a maintenance task fails"
        case .securityDropped: return "When a security object is removed"
        case .securityToggleFailed: return "When a security setting change fails"
        case .tableStructureUpdated: return "When a table structure change is applied"
        case .indexCreated: return "When a new index is created"
        case .indexDropped: return "When an index is removed"
        case .indexRebuilt: return "When an index rebuild completes"
        case .indexRebuildFailed: return "When an index rebuild fails"
        case .databaseCreated: return "When a new database is created"
        case .databaseCreationFailed: return "When database creation fails"
        case .databaseSwitched: return "When the active database changes"
        case .databaseSwitchFailed: return "When a database switch fails"
        case .databasePropertiesError: return "When database property changes fail"
        case .databasePropertiesSaved: return "When database properties are saved"
        case .jobStarted: return "When a SQL Agent job starts running"
        case .jobStopped: return "When a SQL Agent job is stopped"
        case .jobError: return "When a SQL Agent job encounters an error"
        case .jobScheduleCreated: return "When a new job schedule is created"
        case .jobNotificationSaved: return "When job notification settings are saved"
        case .jobPropertiesSaved: return "When job properties are saved"
        case .generalSuccess: return "When an operation succeeds"
        case .generalError: return "When an unexpected error occurs"
        case .generalInfo: return "General informational alerts"
        }
    }

    // MARK: - Visuals

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

    var displayDescription: String {
        switch self {
        case .connection: return "Connection status and errors"
        case .objectBrowser: return "Object lifecycle, extensions, and maintenance"
        case .tableStructure: return "Schema changes and index operations"
        case .database: return "Database creation, switching, and properties"
        case .jobs: return "SQL Agent job activity"
        case .general: return "App-wide success, error, and info alerts"
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

    /// Whether all categories in this group are critical defaults.
    var isAllCritical: Bool {
        categories.allSatisfy(\.isCriticalDefault)
    }

    /// Whether any categories in this group are critical defaults.
    var hasCriticalCategories: Bool {
        categories.contains(where: \.isCriticalDefault)
    }
}
