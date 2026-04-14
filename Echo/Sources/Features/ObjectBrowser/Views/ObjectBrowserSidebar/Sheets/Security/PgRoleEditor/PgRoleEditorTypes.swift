import Foundation
import PostgresKit

// MARK: - Window Value

struct PgRoleEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let roleName: String?

    var isEditing: Bool { roleName != nil }
}

// MARK: - Pages

enum PgRoleEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case privileges
    case membership
    case parameters
    case sql

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .privileges: "Privileges"
        case .membership: "Membership"
        case .parameters: "Parameters"
        case .sql: "SQL Preview"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.circle"
        case .privileges: "lock.shield"
        case .membership: "person.2"
        case .parameters: "slider.horizontal.3"
        case .sql: "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - Membership Draft

struct PgRoleMembershipDraft: Identifiable, Hashable {
    let id: UUID
    let roleName: String
    var adminOption: Bool
    var inheritOption: Bool
    var setOption: Bool

    init(
        id: UUID = UUID(),
        roleName: String,
        adminOption: Bool = false,
        inheritOption: Bool = true,
        setOption: Bool = true
    ) {
        self.id = id
        self.roleName = roleName
        self.adminOption = adminOption
        self.inheritOption = inheritOption
        self.setOption = setOption
    }
}

// MARK: - Parameter Draft

struct PgRoleParameterDraft: Identifiable, Hashable {
    let id: UUID
    var name: String
    var value: String

    init(id: UUID = UUID(), name: String = "", value: String = "") {
        self.id = id
        self.name = name
        self.value = value
    }
}
