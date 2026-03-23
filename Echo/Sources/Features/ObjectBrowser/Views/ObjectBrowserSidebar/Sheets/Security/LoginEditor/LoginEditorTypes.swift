import Foundation
import SQLServerKit

// MARK: - Window Value

struct LoginEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let existingLoginName: String?
}

// MARK: - Pages

enum LoginEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case serverRoles
    case userMapping
    case securables
    case status

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .serverRoles: "Server Roles"
        case .userMapping: "User Mapping"
        case .securables: "Securables"
        case .status: "Status"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.circle"
        case .serverRoles: "shield"
        case .userMapping: "externaldrive.connected.to.line.below"
        case .securables: "lock.shield"
        case .status: "power"
        }
    }
}

// MARK: - Auth Type

enum LoginAuthType: Hashable {
    case sql
    case windows
}

// MARK: - Server Role Entry

struct LoginEditorRoleEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
    let originallyMember: Bool
}

// MARK: - Database Mapping Entry

struct LoginEditorMappingEntry: Identifiable, Hashable {
    var id: String { databaseName }
    let databaseName: String
    var isMapped: Bool
    var userName: String?
    var defaultSchema: String?
}

// MARK: - Database Role Membership Entry

struct LoginEditorDBRoleEntry: Identifiable, Hashable {
    var id: String { roleName }
    let roleName: String
    var isMember: Bool
}

// MARK: - Server Permission Entry

struct LoginEditorPermissionEntry: Identifiable, Hashable {
    var id: String { permission }
    let permission: String
    var isGranted: Bool
    var withGrantOption: Bool
    var isDenied: Bool
    let originalState: PermissionState
}
