import Foundation

enum PgDumpFormat: String, CaseIterable, Identifiable {
    case plain = "Plain SQL"
    case custom = "Custom"
    case tar = "Tar"
    case directory = "Directory"

    var id: String { rawValue }

    var pgDumpFlag: String {
        switch self {
        case .plain: return "p"
        case .custom: return "c"
        case .tar: return "t"
        case .directory: return "d"
        }
    }
}

enum PostgresBackupPhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

enum PostgresRestorePhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

struct PgRestoreListItem: Identifiable {
    let id: Int
    let line: String
    let type: String
    let schema: String?
    let name: String
}

enum PgBackupPage: String, CaseIterable, Hashable {
    case general
    case scope
    case options
    case advanced

    var title: String {
        switch self {
        case .general: return "General"
        case .scope: return "Scope"
        case .options: return "Options"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general: return "doc.badge.plus"
        case .scope: return "square.dashed"
        case .options: return "gearshape"
        case .advanced: return "wrench"
        }
    }
}

enum PgRestorePage: String, CaseIterable, Hashable {
    case general
    case options
    case advanced

    var title: String {
        switch self {
        case .general: return "General"
        case .options: return "Options"
        case .advanced: return "Advanced"
        }
    }

    var icon: String {
        switch self {
        case .general: return "arrow.counterclockwise"
        case .options: return "gearshape"
        case .advanced: return "wrench"
        }
    }
}
