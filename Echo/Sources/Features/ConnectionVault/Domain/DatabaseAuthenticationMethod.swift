import Foundation

/// Supported authentication flows for database connections.
public enum DatabaseAuthenticationMethod: String, CaseIterable, Codable, Hashable, Sendable {
    case sqlPassword
    case windowsIntegrated
    case accessToken
    /// The user's Kerberos ticket (PostgreSQL GSSAPI); no password is stored or sent.
    case kerberos

    public var displayName: String {
        switch self {
        case .sqlPassword:
            return "SQL authentication"
        case .windowsIntegrated:
            return "Windows integrated"
        case .accessToken:
            return "Access token (Entra ID)"
        case .kerberos:
            return "Kerberos"
        }
    }

    /// The Mechanism menu's words for an engine: PostgreSQL says Password where SQL Server says
    /// SQL authentication (Echo Labs round 23, Kerberos: KP1, KN1).
    func displayName(for type: DatabaseType) -> String {
        self == .sqlPassword && type == .postgresql ? "Password" : displayName
    }

    /// Whether the UI should prompt for a Windows domain in addition to username/password.
    public var requiresDomain: Bool {
        switch self {
        case .sqlPassword, .accessToken, .kerberos:
            return false
        case .windowsIntegrated:
            return true
        }
    }

    /// Whether credentials can come from an identity/credential store instead of manual entry.
    public var supportsExternalCredentials: Bool { true }

    /// Whether this method uses an access token instead of username/password.
    public var usesAccessToken: Bool {
        self == .accessToken
    }

    /// Whether the sheet asks for a password (Kerberos uses the ticket instead).
    public var usesPassword: Bool {
        self != .kerberos
    }
}
