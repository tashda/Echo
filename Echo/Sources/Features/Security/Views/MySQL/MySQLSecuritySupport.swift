import MySQLKit
import Foundation

struct MySQLPrivilegeGrantee: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case user
        case role
    }

    let kind: Kind
    let username: String
    let host: String

    var id: String { "\(kind.rawValue):\(username)@\(host)" }
    var accountName: String { "'\(username)'@'\(host)'" }
}

extension MySQLUserAccount: @retroactive Identifiable {
    public var id: String { "\(username)@\(host)" }
    var accountName: String { "'\(username)'@'\(host)'" }
}

extension MySQLRoleDefinition: @retroactive Identifiable {
    public var id: String { "\(name)@\(host)" }
    var accountName: String { "'\(name)'@'\(host)'" }
}

extension MySQLRoleAssignment: @retroactive Identifiable {
    public var id: String { "\(roleName)@\(roleHost)->\(grantee)" }
}

extension MySQLPrivilegeGrant: @retroactive Identifiable {
    public var id: String {
        "\(grantee)|\(tableSchema ?? "")|\(tableName ?? "")|\(privilegeType)"
    }
}

extension MySQLPrivilegeGrant {
    var parsedGrantee: MySQLPrivilegeGrantee? {
        let trimmed = grantee.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let atRange = trimmed.range(of: "'@'", options: .backwards),
            trimmed.hasPrefix("'"),
            trimmed.hasSuffix("'")
        else {
            return nil
        }

        let username = String(trimmed[trimmed.index(after: trimmed.startIndex)..<atRange.lowerBound])
        let hostStart = atRange.upperBound
        let hostEnd = trimmed.index(before: trimmed.endIndex)
        let host = String(trimmed[hostStart..<hostEnd])
        return MySQLPrivilegeGrantee(kind: .user, username: username, host: host)
    }
}

extension MySQLRoutineInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(type).\(name)" }
}

extension MySQLTriggerInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(table).\(name)" }
}

extension MySQLEventInfo: @retroactive Identifiable {
    public var id: String { "\(schema).\(name)" }
}
