import Foundation
import SQLServerKit

enum BackupPhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

enum RestorePhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

/// The destination type for a backup operation in the UI.
enum BackupDestinationType: String, CaseIterable, Hashable {
    case disk = "Disk"
    case url = "URL"
}

/// The scope of a backup operation in the UI.
enum BackupScopeType: String, CaseIterable, Hashable {
    case database = "Database"
    case files = "Files"
    case filegroups = "Filegroups"
}

/// A single backup destination entry in the UI list.
struct BackupDestinationEntry: Identifiable {
    let id = UUID()
    var path: String = ""
}

/// A selectable database file entry for file/filegroup backup scope.
struct SelectableDatabaseFile: Identifiable {
    var id: Int32 { fileInfo.fileID }
    let fileInfo: SQLServerDatabaseFileInfo
    var isSelected: Bool = false
}

enum MSSQLBackupPage: String, CaseIterable, Hashable {
    case general
    case media
    case options
    case encryption

    var title: String {
        switch self {
        case .general: return "General"
        case .media: return "Media"
        case .options: return "Options"
        case .encryption: return "Encryption"
        }
    }

    var icon: String {
        switch self {
        case .general: return "doc.badge.plus"
        case .media: return "opticaldisc"
        case .options: return "gearshape"
        case .encryption: return "lock.shield"
        }
    }
}

enum MSSQLRestorePage: String, CaseIterable, Hashable {
    case general
    case files
    case options
    case recovery
    case verify

    var title: String {
        switch self {
        case .general: return "General"
        case .files: return "Files"
        case .options: return "Options"
        case .recovery: return "Recovery"
        case .verify: return "Verify"
        }
    }

    var icon: String {
        switch self {
        case .general: return "arrow.counterclockwise"
        case .files: return "doc.on.doc"
        case .options: return "gearshape"
        case .recovery: return "clock.arrow.circlepath"
        case .verify: return "checkmark.shield"
        }
    }
}

enum MSSQLRestoreRecoveryMode: String, CaseIterable {
    case recovery = "RECOVERY"
    case noRecovery = "NORECOVERY"
    case standby = "STANDBY"

    var title: String {
        switch self {
        case .recovery: return "Recovery"
        case .noRecovery: return "No Recovery"
        case .standby: return "Standby"
        }
    }
}

struct FileRelocationEntry: Identifiable {
    let id = UUID()
    let logicalName: String
    let originalPath: String
    var relocatedPath: String
}
