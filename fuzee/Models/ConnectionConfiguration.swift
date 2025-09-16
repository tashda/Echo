import Foundation

/// Enhanced connection configuration with advanced PostgreSQL options

struct ConnectionConfiguration: Codable, Hashable {
    // Basic connection info
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var keychainIdentifier: String?

    // Security settings
    var useTLS: Bool = true
    var tlsMode: TLSMode = .prefer
    var verifySSLCertificate: Bool = true

    // Connection behavior
    var connectionTimeout: TimeInterval = 30
    var queryTimeout: TimeInterval = 60
    var maxRetries: Int = 3

    // Advanced settings
    var applicationName: String = "Fuzee"
    var searchPath: [String] = ["public"]
    var autocommit: Bool = true

    // Connection pooling (future enhancement)
    var useConnectionPooling: Bool = false
    var maxPoolSize: Int = 10
    var minPoolSize: Int = 1

    var id: UUID = UUID()

    // Convert to SavedConnection for compatibility
    var asSavedConnection: SavedConnection {
        SavedConnection(
            id: id,
            connectionName: connectionName,
            host: host,
            port: port,
            database: database,
            username: username,
            keychainIdentifier: keychainIdentifier,
            useTLS: useTLS
        )
    }

    // Create from SavedConnection

    static func from(_ savedConnection: SavedConnection) -> ConnectionConfiguration {
        ConnectionConfiguration(
            connectionName: savedConnection.connectionName,
            host: savedConnection.host,
            port: savedConnection.port,
            database: savedConnection.database,
            username: savedConnection.username,
            keychainIdentifier: savedConnection.keychainIdentifier,
            useTLS: savedConnection.useTLS,
            id: savedConnection.id
        )
    }
}

enum TLSMode: String, CaseIterable, Codable {
    case disable = "disable"
    case allow = "allow"
    case prefer = "prefer"
    case require = "require"
    case verifyCA = "verify-ca"
    case verifyFull = "verify-full"

    var description: String {
        switch self {
        case .disable:
            return "Disable - No SSL/TLS encryption"
        case .allow:
            return "Allow - Try non-SSL first, then SSL if required"
        case .prefer:
            return "Prefer - Try SSL first, fall back to non-SSL"
        case .require:
            return "Require - SSL required, but don't verify certificates"
        case .verifyCA:
            return "Verify CA - SSL required, verify certificate authority"
        case .verifyFull:
            return "Verify Full - SSL required, verify certificate and hostname"
        }
    }

    var requiresTLS: Bool {
        switch self {
        case .disable, .allow:
            return false
        case .prefer, .require, .verifyCA, .verifyFull:
            return true
        }
    }
}

// Connection templates for common scenarios

extension ConnectionConfiguration {
    static let templates: [ConnectionTemplate] = [
        ConnectionTemplate(
            name: "Local PostgreSQL",
            description: "Standard local PostgreSQL instance",
            configuration: ConnectionConfiguration(
                connectionName: "Local PostgreSQL",
                host: "localhost",
                port: 5432,
                database: "postgres",
                username: "postgres",
                useTLS: false,
                tlsMode: .disable
            )
        ),
        ConnectionTemplate(
            name: "Secure Remote Server",
            description: "Production server with full SSL verification",
            configuration: ConnectionConfiguration(
                connectionName: "Production Server",
                host: "",
                port: 5432,
                database: "",
                username: "",
                useTLS: true,
                tlsMode: .verifyFull,
                connectionTimeout: 10,
                queryTimeout: 30
            )
        ),
        ConnectionTemplate(
            name: "Docker Container",
            description: "PostgreSQL running in Docker",
            configuration: ConnectionConfiguration(
                connectionName: "Docker PostgreSQL",
                host: "localhost",
                port: 5432,
                database: "postgres",
                username: "postgres",
                useTLS: false,
                tlsMode: .disable,
                connectionTimeout: 5
            )
        )
    ]
}

struct ConnectionTemplate {
    let name: String
    let description: String
    let configuration: ConnectionConfiguration
}

// Connection validation

extension ConnectionConfiguration {
    var isValid: Bool {
        !connectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !database.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && port > 0 && port <= 65535
    }

    var validationErrors: [String] {
        var errors: [String] = []

        if connectionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Connection name is required")
        }

        if host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Host is required")
        }

        if database.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Database name is required")
        }

        if username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Username is required")
        }

        if port <= 0 || port > 65535 {
            errors.append("Port must be between 1 and 65535")
        }

        if connectionTimeout <= 0 {
            errors.append("Connection timeout must be positive")
        }

        if queryTimeout <= 0 {
            errors.append("Query timeout must be positive")
        }

        return errors
    }
}