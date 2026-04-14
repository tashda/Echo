import Foundation

// MARK: - Window Value

struct DatabaseMailEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
}

// MARK: - Pages

enum DatabaseMailEditorPage: String, CaseIterable, Hashable, Identifiable {
    case profiles
    case accounts
    case security
    case settings
    case status
    case queue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profiles: "Profiles"
        case .accounts: "Accounts"
        case .security: "Security"
        case .settings: "Settings"
        case .status: "Status"
        case .queue: "Mail Queue"
        }
    }

    var icon: String {
        switch self {
        case .profiles: "person.crop.rectangle.stack"
        case .accounts: "envelope"
        case .security: "lock.shield"
        case .settings: "gearshape"
        case .status: "power"
        case .queue: "tray"
        }
    }
}
