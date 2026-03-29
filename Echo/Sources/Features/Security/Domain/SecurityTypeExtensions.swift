import SQLServerKit

// MARK: - Identifiable conformance for security types used in SwiftUI Tables

extension UserInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension RoleInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension ApplicationRoleInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension SQLServerKit.SchemaInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension ServerLoginInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension ServerRoleInfo: @retroactive Identifiable {
    public var id: String { name }
}

extension SQLServerServerSecurityClient.CredentialInfo: @retroactive Identifiable {
    public var id: String { name }
}
