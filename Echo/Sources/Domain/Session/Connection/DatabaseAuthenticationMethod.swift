import Foundation

/// Supported authentication flows for database connections.
public enum DatabaseAuthenticationMethod: String, CaseIterable, Codable, Hashable, Sendable {
    case sqlPassword
    case windowsIntegrated

    public var displayName: String {
        switch self {
        case .sqlPassword:
            return "SQL authentication"
        case .windowsIntegrated:
            return "Windows integrated"
        }
    }

    /// Whether the UI should prompt for a Windows domain in addition to username/password.
    public var requiresDomain: Bool {
        switch self {
        case .sqlPassword:
            return false
        case .windowsIntegrated:
            return true
        }
    }

    /// Whether credentials can come from an identity/credential store instead of manual entry.
    public var supportsExternalCredentials: Bool {
        switch self {
        case .sqlPassword:
            return true
        case .windowsIntegrated:
            return false
        }
    }
}
