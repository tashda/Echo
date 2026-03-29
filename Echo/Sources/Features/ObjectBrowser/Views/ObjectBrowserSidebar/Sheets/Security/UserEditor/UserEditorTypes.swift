import Foundation
import SQLServerKit

// MARK: - Window Value

struct UserEditorWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let databaseName: String
    let existingUserName: String?
}

// MARK: - Pages

enum UserEditorPage: String, CaseIterable, Hashable, Identifiable {
    case general
    case ownedSchemas
    case membership
    case securables
    case extendedProperties

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .ownedSchemas: "Owned Schemas"
        case .membership: "Membership"
        case .securables: "Securables"
        case .extendedProperties: "Extended Properties"
        }
    }

    var icon: String {
        switch self {
        case .general: "person.fill"
        case .ownedSchemas: "folder"
        case .membership: "person.2"
        case .securables: "lock.shield"
        case .extendedProperties: "list.bullet.rectangle"
        }
    }
}

// MARK: - User Type Choice

enum DatabaseUserTypeChoice: String, Hashable, CaseIterable, Identifiable {
    case mappedToLogin
    case withPassword
    case withoutLogin
    case windowsUser
    case mappedToCertificate
    case mappedToAsymmetricKey

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mappedToLogin: "SQL user with login"
        case .withPassword: "SQL user with password"
        case .withoutLogin: "SQL user without login"
        case .windowsUser: "Windows user"
        case .mappedToCertificate: "User mapped to a certificate"
        case .mappedToAsymmetricKey: "User mapped to an asymmetric key"
        }
    }
}

// MARK: - Schema Ownership Entry

struct SchemaOwnerEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let currentOwner: String?
    var isOwned: Bool
    let originallyOwned: Bool

    var isSystemSchema: Bool {
        ["dbo", "guest", "INFORMATION_SCHEMA", "sys", "db_owner", "db_accessadmin",
         "db_securityadmin", "db_ddladmin", "db_backupoperator", "db_datareader",
         "db_datawriter", "db_denydatareader", "db_denydatawriter"].contains(name)
    }
}

// MARK: - Role Membership Entry

struct UserEditorRoleMemberEntry: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let isFixed: Bool
    var isMember: Bool
    let originallyMember: Bool
}

// MARK: - Securable Entry

struct SecurableEntry: Identifiable, Hashable {
    let id: UUID
    let securable: SecurableReference
    var permissions: [PermissionGridRow]

    static func == (lhs: SecurableEntry, rhs: SecurableEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct SecurableReference: Hashable {
    let typeName: String
    let schemaName: String?
    let objectName: String
    let objectKind: ObjectKind?
}

// MARK: - Permission Grid Row

struct PermissionGridRow: Identifiable, Hashable {
    var id: String { permission }
    let permission: String
    var isGranted: Bool
    var withGrantOption: Bool
    var isDenied: Bool
    let originalState: PermissionState
}

struct PermissionState: Hashable {
    let isGranted: Bool
    let withGrantOption: Bool
    let isDenied: Bool

    static let none = PermissionState(isGranted: false, withGrantOption: false, isDenied: false)
}

// MARK: - Extended Property Entry

struct ExtendedPropertyEntry: Identifiable, Hashable {
    let id: UUID
    var name: String
    var value: String
    let isNew: Bool
    let originalName: String?
    let originalValue: String?

    var isDeleted: Bool = false
}
