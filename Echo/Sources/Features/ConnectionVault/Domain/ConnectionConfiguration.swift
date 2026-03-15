import Foundation

/// Enhanced connection configuration with advanced PostgreSQL options

struct ConnectionConfiguration: Codable, Hashable {
    // Basic connection info
    var connectionName: String
    var host: String
    var port: Int
    var database: String
    var username: String
    var authenticationMethod: DatabaseAuthenticationMethod
    var domain: String
    var keychainIdentifier: String?
    var credentialSource: CredentialSource = .manual
    var identityID: UUID?
    var folderID: UUID?

    // Security settings
    var useTLS: Bool = true
    var trustServerCertificate: Bool = false
    var tlsMode: TLSMode = .prefer
    var sslRootCertPath: String?
    var sslCertPath: String?
    var sslKeyPath: String?
    var verifySSLCertificate: Bool = true
    var mssqlEncryptionMode: MSSQLEncryptionMode = .optional
    var readOnlyIntent: Bool = false

    // Connection behavior
    var connectionTimeout: TimeInterval = 30
    var queryTimeout: TimeInterval = 60
    var maxRetries: Int = 3

    // Advanced settings
    var applicationName: String = "Echo"
    var searchPath: [String] = ["public"]
    var autocommit: Bool = true

    // Connection pooling (future enhancement)
    var useConnectionPooling: Bool = false
    var maxPoolSize: Int = 10
    var minPoolSize: Int = 1

    var id: UUID = UUID()

    init(
        connectionName: String,
        host: String,
        port: Int,
        database: String,
        username: String,
        authenticationMethod: DatabaseAuthenticationMethod = .sqlPassword,
        domain: String = "",
        keychainIdentifier: String? = nil,
        credentialSource: CredentialSource = .manual,
        identityID: UUID? = nil,
        folderID: UUID? = nil,
        useTLS: Bool = true,
        trustServerCertificate: Bool = false,
        tlsMode: TLSMode = .prefer,
        sslRootCertPath: String? = nil,
        sslCertPath: String? = nil,
        sslKeyPath: String? = nil,
        verifySSLCertificate: Bool = true,
        mssqlEncryptionMode: MSSQLEncryptionMode = .optional,
        readOnlyIntent: Bool = false,
        connectionTimeout: TimeInterval = 30,
        queryTimeout: TimeInterval = 60,
        maxRetries: Int = 3,
        applicationName: String = "Echo",
        searchPath: [String] = ["public"],
        autocommit: Bool = true,
        useConnectionPooling: Bool = false,
        maxPoolSize: Int = 10,
        minPoolSize: Int = 1,
        id: UUID = UUID()
    ) {
        self.connectionName = connectionName
        self.host = host
        self.port = port
        self.database = database
        self.username = username
        self.authenticationMethod = authenticationMethod
        self.domain = domain
        self.keychainIdentifier = keychainIdentifier
        self.credentialSource = credentialSource
        self.identityID = identityID
        self.folderID = folderID
        self.useTLS = useTLS
        self.trustServerCertificate = trustServerCertificate
        self.tlsMode = tlsMode
        self.sslRootCertPath = sslRootCertPath
        self.sslCertPath = sslCertPath
        self.sslKeyPath = sslKeyPath
        self.verifySSLCertificate = verifySSLCertificate
        self.mssqlEncryptionMode = mssqlEncryptionMode
        self.readOnlyIntent = readOnlyIntent
        self.connectionTimeout = connectionTimeout
        self.queryTimeout = queryTimeout
        self.maxRetries = maxRetries
        self.applicationName = applicationName
        self.searchPath = searchPath
        self.autocommit = autocommit
        self.useConnectionPooling = useConnectionPooling
        self.maxPoolSize = maxPoolSize
        self.minPoolSize = minPoolSize
        self.id = id
    }

    // Convert to SavedConnection for compatibility
    var asSavedConnection: SavedConnection {
        SavedConnection(
            id: id,
            connectionName: connectionName,
            host: host,
            port: port,
            database: database,
            username: username,
            authenticationMethod: authenticationMethod,
            domain: domain,
            credentialSource: credentialSource,
            identityID: identityID,
            keychainIdentifier: keychainIdentifier,
            folderID: folderID,
            useTLS: useTLS,
            trustServerCertificate: trustServerCertificate,
            tlsMode: tlsMode,
            sslRootCertPath: sslRootCertPath,
            sslCertPath: sslCertPath,
            sslKeyPath: sslKeyPath,
            mssqlEncryptionMode: mssqlEncryptionMode,
            readOnlyIntent: readOnlyIntent
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
            authenticationMethod: savedConnection.authenticationMethod,
            domain: savedConnection.domain,
            keychainIdentifier: savedConnection.keychainIdentifier,
            credentialSource: savedConnection.credentialSource,
            identityID: savedConnection.identityID,
            folderID: savedConnection.folderID,
            useTLS: savedConnection.useTLS,
            trustServerCertificate: savedConnection.trustServerCertificate,
            tlsMode: savedConnection.tlsMode,
            sslRootCertPath: savedConnection.sslRootCertPath,
            sslCertPath: savedConnection.sslCertPath,
            sslKeyPath: savedConnection.sslKeyPath,
            mssqlEncryptionMode: savedConnection.mssqlEncryptionMode,
            readOnlyIntent: savedConnection.readOnlyIntent,
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

enum MSSQLEncryptionMode: String, CaseIterable, Codable, Sendable {
    case optional
    case mandatory
    case strict

    var description: String {
        switch self {
        case .optional: return "Optional - Use encryption if available"
        case .mandatory: return "Mandatory - Require encryption"
        case .strict: return "Strict - TDS 8.0 strict mode"
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
        let trimmedName = connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

        let credentialsValid: Bool
        switch credentialSource {
        case .manual:
            credentialsValid = !trimmedUsername.isEmpty
        case .inherit:
            credentialsValid = true
        case .identity:
            credentialsValid = identityID != nil
        }

        return !trimmedName.isEmpty &&
        !trimmedHost.isEmpty &&
        credentialsValid &&
        port > 0 && port <= 65535 &&
        !database.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            errors.append("Database is required")
        }

        if credentialSource == .manual && username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Username is required")
        }

        if credentialSource == .identity && identityID == nil {
            errors.append("Select an identity to use")
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
