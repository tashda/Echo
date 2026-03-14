import Foundation

/// Supported authentication flows for database connections.
public enum DatabaseAuthenticationMethod: String, CaseIterable, Codable, Hashable, Sendable {
    case sqlPassword
    case windowsIntegrated
    case accessToken

    public var displayName: String {
        switch self {
        case .sqlPassword:
            return "SQL authentication"
        case .windowsIntegrated:
            return "Windows integrated"
        case .accessToken:
            return "Access token (Entra ID)"
        }
    }

    /// Whether the UI should prompt for a Windows domain in addition to username/password.
    public var requiresDomain: Bool {
        switch self {
        case .sqlPassword, .accessToken:
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
        case .windowsIntegrated, .accessToken:
            return false
        }
    }

    /// Whether this method uses an access token instead of username/password.
    public var usesAccessToken: Bool {
        self == .accessToken
    }
}
