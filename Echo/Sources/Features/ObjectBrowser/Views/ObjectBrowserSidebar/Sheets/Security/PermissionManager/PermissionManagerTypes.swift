import Foundation
import SQLServerKit

// MARK: - Window Value

struct PermissionManagerWindowValue: Codable, Hashable {
    let connectionSessionID: UUID
    let databaseName: String
    let principalName: String?
}

// MARK: - Pages

enum PermissionManagerPage: String, CaseIterable, Hashable, Identifiable {
    case securables
    case effectivePermissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .securables: "Securables"
        case .effectivePermissions: "Effective Permissions"
        }
    }

    var icon: String {
        switch self {
        case .securables: "lock.shield"
        case .effectivePermissions: "checklist"
        }
    }
}

// MARK: - Principal Choice

struct PrincipalChoice: Identifiable, Hashable {
    var id: String { "\(type):\(name)" }
    let name: String
    let type: String
    let isFixed: Bool

    var displayType: String {
        switch type {
        case "S", "U": "SQL User"
        case "R": "Database Role"
        case "A": "Application Role"
        case "G": "Windows Group"
        case "K": "Asymmetric Key User"
        case "C": "Certificate User"
        case "E": "External User"
        case "X": "External Group"
        default: "User"
        }
    }
}
