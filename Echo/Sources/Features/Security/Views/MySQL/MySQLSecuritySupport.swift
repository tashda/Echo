import MySQLKit

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
