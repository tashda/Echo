import SwiftUI

// MARK: - Supporting Types

enum LoginPage: String, Hashable {
    case general
    case serverRoles
    case databaseMapping

    var title: String {
        switch self {
        case .general: "General"
        case .serverRoles: "Server Roles"
        case .databaseMapping: "User Mapping"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.circle"
        case .serverRoles: "shield"
        case .databaseMapping: "externaldrive.connected.to.line.below"
        }
    }
}

enum AuthType: Hashable {
    case sql
    case windows
}

struct RoleEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
}

struct DatabaseMappingEntry: Identifiable, Hashable {
    var id: String { databaseName }
    let databaseName: String
    var isMapped: Bool
    var userName: String?
    var defaultSchema: String?
}

struct DatabaseRoleMembershipEntry: Identifiable, Hashable {
    var id: String { roleName }
    let roleName: String
    var isMember: Bool
}
