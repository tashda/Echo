import Foundation

/// Typed notification events with structured payloads.
///
/// All human-readable messages are formatted here — call sites pass only data.
/// To change a message, edit the single `message` property below.
enum NotificationEvent {

    // MARK: - Connection

    case connected(displayName: String)
    case disconnected(displayName: String)
    case connectionFailed(displayName: String, reason: String? = nil)

    // MARK: - Database

    case databaseCreated(name: String)
    case databaseCreationFailed(name: String, reason: String)
    case databaseSwitched(name: String)
    case databaseSwitchFailed(name: String, reason: String)
    case databasePropertiesSaved(detail: String)
    case databasePropertiesError(reason: String)

    // MARK: - Object Operations

    case objectDropped(name: String)
    case objectDropFailed(name: String, reason: String)
    case objectRenamed(oldName: String, newName: String)
    case objectRenameFailed(name: String, reason: String)
    case objectCreated(name: String)
    case objectTruncated(name: String)
    case objectTruncateFailed(name: String, reason: String)

    // MARK: - Extensions

    case extensionInstalled(name: String)
    case extensionFailed(name: String, reason: String)

    // MARK: - Index Operations

    case indexCreated(name: String)
    case indexDropped(name: String)
    case indexRebuilding(name: String)
    case indexRebuilt(name: String)
    case indexRebuildFailed(name: String, reason: String)

    // MARK: - Maintenance

    case vacuumCompleted(schema: String, table: String)
    case vacuumAnalyzeCompleted(schema: String, table: String)
    case vacuumFullCompleted(schema: String, table: String)
    case analyzeCompleted(schema: String, table: String)
    case reindexCompleted(schema: String, table: String)
    case backupCompleted(database: String, destination: String)
    case backupFailed(database: String, reason: String)
    case restoreCompleted(database: String)
    case restoreFailed(database: String, reason: String)
    case maintenanceFailed(operation: String, reason: String)
    case processTerminated(pid: Int)
    case processTerminateFailed(pid: Int, reason: String)

    // MARK: - Security

    case securityObjectDropped(type: String, name: String)
    case securityDropFailed(reason: String)
    case securityToggleFailed(reason: String)

    // MARK: - Jobs

    case jobStarted(name: String)
    case jobStopped(name: String)
    case jobCompleted(name: String)
    case jobFailed(name: String)
    case jobError(reason: String)
    case jobScheduleCreated
    case jobNotificationSaved
    case jobPropertiesSaved

    // MARK: - General

    case info(message: String)
    case success(message: String)
    case error(message: String)

    // MARK: - Derived Properties

    var category: NotificationCategory {
        switch self {
        case .connected: return .connectionConnected
        case .disconnected: return .connectionDisconnected
        case .connectionFailed: return .connectionFailed
        case .databaseCreated: return .databaseCreated
        case .databaseCreationFailed: return .databaseCreationFailed
        case .databaseSwitched: return .databaseSwitched
        case .databaseSwitchFailed: return .databaseSwitchFailed
        case .databasePropertiesSaved: return .databasePropertiesSaved
        case .databasePropertiesError: return .databasePropertiesError
        case .objectDropped: return .objectDropped
        case .objectDropFailed: return .generalError
        case .objectRenamed: return .objectRenamed
        case .objectRenameFailed: return .generalError
        case .objectCreated: return .objectCreated
        case .objectTruncated: return .objectTruncated
        case .objectTruncateFailed: return .generalError
        case .extensionInstalled: return .extensionInstalled
        case .extensionFailed: return .extensionFailed
        case .indexCreated: return .indexCreated
        case .indexDropped: return .indexDropped
        case .indexRebuilding: return .generalInfo
        case .indexRebuilt: return .indexRebuilt
        case .indexRebuildFailed: return .indexRebuildFailed
        case .backupCompleted: return .maintenanceCompleted
        case .backupFailed: return .maintenanceFailed
        case .restoreCompleted: return .maintenanceCompleted
        case .restoreFailed: return .maintenanceFailed
        case .vacuumCompleted, .vacuumAnalyzeCompleted, .vacuumFullCompleted,
             .analyzeCompleted, .reindexCompleted, .processTerminated:
            return .maintenanceCompleted
        case .maintenanceFailed, .processTerminateFailed:
            return .maintenanceFailed
        case .securityObjectDropped: return .securityDropped
        case .securityDropFailed: return .generalError
        case .securityToggleFailed: return .securityToggleFailed
        case .jobStarted: return .jobStarted
        case .jobStopped: return .jobStopped
        case .jobCompleted: return .jobStarted
        case .jobFailed: return .jobError
        case .jobError: return .jobError
        case .jobScheduleCreated: return .jobScheduleCreated
        case .jobNotificationSaved: return .jobNotificationSaved
        case .jobPropertiesSaved: return .jobPropertiesSaved
        case .info: return .generalInfo
        case .success: return .generalSuccess
        case .error: return .generalError
        }
    }

    /// The single source of truth for all notification messages.
    var message: String {
        switch self {
        // Connection
        case .connected(let name): return "Connected to \(name)"
        case .disconnected(let name): return "Disconnected from \(name)"
        case .connectionFailed(let name, let reason):
            if let reason { return "Connection failed: \(name) — \(reason)" }
            return "Connection failed: \(name)"

        // Database
        case .databaseCreated(let name): return "Database \u{201C}\(name)\u{201D} created"
        case .databaseCreationFailed(_, let reason): return "Database creation failed: \(reason)"
        case .databaseSwitched(let name): return "Switched to \(name)"
        case .databaseSwitchFailed(_, let reason): return "Failed to switch: \(reason)"
        case .databasePropertiesSaved(let detail): return detail
        case .databasePropertiesError(let reason): return reason

        // Object Operations
        case .objectDropped(let name): return "Dropped \(name)"
        case .objectDropFailed(let name, let reason): return "Failed to drop \(name): \(reason)"
        case .objectRenamed(let oldName, let newName): return "Renamed \(oldName) to \(newName)"
        case .objectRenameFailed(let name, let reason): return "Failed to rename \(name): \(reason)"
        case .objectCreated(let name): return "Created \(name)"
        case .objectTruncated(let name): return "Truncated \(name)"
        case .objectTruncateFailed(let name, let reason): return "Failed to truncate \(name): \(reason)"

        // Extensions
        case .extensionInstalled(let name): return "Extension \(name) installed"
        case .extensionFailed(let name, let reason): return "Extension \(name) failed: \(reason)"

        // Index Operations
        case .indexCreated(let name): return "Index \u{201C}\(name)\u{201D} created"
        case .indexDropped(let name): return "Index \u{201C}\(name)\u{201D} dropped"
        case .indexRebuilding(let name): return "Rebuilding index \u{201C}\(name)\u{201D}\u{2026}"
        case .indexRebuilt(let name): return "Index \u{201C}\(name)\u{201D} rebuilt"
        case .indexRebuildFailed(_, let reason): return reason

        // Backup & Restore
        case .backupCompleted(let database, let destination): return "Backup completed for \(database) to \(destination)"
        case .backupFailed(let database, let reason): return "Backup failed for \(database): \(reason)"
        case .restoreCompleted(let database): return "Restore completed for \(database)"
        case .restoreFailed(let database, let reason): return "Restore failed for \(database): \(reason)"

        // Maintenance
        case .vacuumCompleted(let schema, let table): return "Vacuum completed on \(schema).\(table)"
        case .vacuumAnalyzeCompleted(let schema, let table): return "Vacuum Analyze completed on \(schema).\(table)"
        case .vacuumFullCompleted(let schema, let table): return "Vacuum Full completed on \(schema).\(table)"
        case .analyzeCompleted(let schema, let table): return "Analyze completed on \(schema).\(table)"
        case .reindexCompleted(let schema, let table): return "Reindex completed on \(schema).\(table)"
        case .maintenanceFailed(let operation, let reason): return "\(operation) failed: \(reason)"
        case .processTerminated(let pid): return "Terminated backend process \(pid)"
        case .processTerminateFailed(let pid, let reason): return "Failed to terminate process \(pid): \(reason)"

        // Security
        case .securityObjectDropped(let type, let name): return "\(type) \u{2018}\(name)\u{2019} dropped"
        case .securityDropFailed(let reason): return "Drop failed: \(reason)"
        case .securityToggleFailed(let reason): return reason

        // Jobs
        case .jobStarted(let name): return "Started: \(name)"
        case .jobStopped(let name): return "Stopped: \(name)"
        case .jobCompleted(let name): return "Completed: \(name)"
        case .jobFailed(let name): return "Failed: \(name)"
        case .jobError(let reason): return reason
        case .jobScheduleCreated: return "Schedule created"
        case .jobNotificationSaved: return "Notification saved"
        case .jobPropertiesSaved: return "Properties saved"

        // General
        case .info(let message): return message
        case .success(let message): return message
        case .error(let message): return message
        }
    }

    /// Override icon for specific events, otherwise use the category default.
    var icon: String? {
        switch self {
        case .indexRebuilding: return "arrow.triangle.2.circlepath"
        default: return nil
        }
    }

    /// Override style for specific events, otherwise use the category default.
    var style: StatusToastView.StatusToastStyle? {
        switch self {
        case .indexRebuilding: return .info
        default: return nil
        }
    }

    /// Override duration for specific events.
    var duration: TimeInterval? {
        switch self {
        case .connectionFailed, .databaseSwitchFailed, .jobError: return 5.0
        default: return nil
        }
    }
}
