import Foundation

// MARK: - Window Value

struct RoleEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let databaseName: String
    let existingRoleName: String?
}

// MARK: - Pages

enum RoleEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case membership
    case securables

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .membership: "Members"
        case .securables: "Securables"
        }
    }

    var icon: String {
        switch self {
        case .general: "shield.fill"
        case .membership: "person.2"
        case .securables: "lock.shield"
        }
    }
}

// MARK: - Role Member Entry

struct RoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    var isMember: Bool
    let originallyMember: Bool
}
