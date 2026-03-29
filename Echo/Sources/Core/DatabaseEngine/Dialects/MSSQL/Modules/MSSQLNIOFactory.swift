import Foundation
import SQLServerKit
import OSLog

extension MSSQLEncryptionMode {
    var asSQLServerEncryptionMode: SQLServerEncryptionMode {
        switch self {
        case .optional: .optional
        case .mandatory: .mandatory
        case .strict: .strict
        }
    }
}

struct MSSQLNIOFactory: DatabaseFactory {
    private let logger = Logger.mssql

    static func makeAuthentication(
        from authentication: DatabaseAuthenticationConfiguration
    ) throws -> SQLServerAuthentication {
        switch authentication.method {
        case .sqlPassword:
            guard let password = authentication.password else {
                throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
            }
            return .sqlPassword(
                username: authentication.username,
                password: password
            )
        case .windowsIntegrated:
            return .windowsIntegrated(
                username: authentication.username,
                password: authentication.password ?? "",
                domain: authentication.domain
            )
        case .accessToken:
            guard let token = authentication.password, !token.isEmpty else {
                throw DatabaseError.authenticationFailed("Access token is required for Entra ID authentication")
            }
            return .accessToken(token: token)
        }
    }

    static func makeClientConfiguration(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool,
        sslRootCertPath: String?,
        mssqlEncryptionMode: MSSQLEncryptionMode,
        readOnlyIntent: Bool,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) throws -> SQLServerClient.Configuration {
        let loginDatabase: String = {
            guard let db = database?.trimmingCharacters(in: .whitespacesAndNewlines), !db.isEmpty else {
                return "master"
            }
            return db
        }()
        let sqlServerAuth = try makeAuthentication(from: authentication)

        var config = SQLServerClient.Configuration(
            hostname: host,
            port: port,
            database: loginDatabase,
            authentication: sqlServerAuth,
            tlsEnabled: tls,
            trustServerCertificate: trustServerCertificate,
            caCertificatePath: sslRootCertPath,
            encryptionMode: mssqlEncryptionMode.asSQLServerEncryptionMode,
            metadataConfiguration: .init(
                includeSystemSchemas: false,
                enableColumnCache: true,
                includeRoutineDefinitions: false,
                includeTriggerDefinitions: true,
                commandTimeout: 30,
                extractParameterDefaults: false,
                preferStoredProcedureColumns: false
            )
        )
        config.connection.readOnlyIntent = readOnlyIntent
        config.connection.connectTimeoutSeconds = connectTimeoutSeconds
        return config
    }

    static func makeConnectionConfiguration(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool,
        sslRootCertPath: String?,
        mssqlEncryptionMode: MSSQLEncryptionMode,
        readOnlyIntent: Bool,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) throws -> SQLServerConnection.Configuration {
        let clientConfiguration = try makeClientConfiguration(
            host: host,
            port: port,
            database: database,
            tls: tls,
            trustServerCertificate: trustServerCertificate,
            sslRootCertPath: sslRootCertPath,
            mssqlEncryptionMode: mssqlEncryptionMode,
            readOnlyIntent: readOnlyIntent,
            authentication: authentication,
            connectTimeoutSeconds: connectTimeoutSeconds
        )
        var configuration = clientConfiguration.connection
        configuration.connectTimeoutSeconds = connectTimeoutSeconds
        return configuration
    }

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool = false,
        tlsMode: TLSMode = .prefer,
        sslRootCertPath: String? = nil,
        sslCertPath: String? = nil,
        sslKeyPath: String? = nil,
        mssqlEncryptionMode: MSSQLEncryptionMode = .optional,
        readOnlyIntent: Bool = false,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        let resolvedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Connect to the target database directly so metadata operations (sys.schemas,
        // sys.objects, etc.) resolve without cross-database three-part naming. Falls back
        // to master only when no database is specified.
        let loginDatabase = (resolvedDatabase?.isEmpty == false) ? resolvedDatabase! : "master"

        logger.info("Connecting to SQL Server at \(host):\(port)/\(loginDatabase)")

        let config = try Self.makeClientConfiguration(
            host: host,
            port: port,
            database: loginDatabase,
            tls: tls,
            trustServerCertificate: trustServerCertificate,
            sslRootCertPath: sslRootCertPath,
            mssqlEncryptionMode: mssqlEncryptionMode,
            readOnlyIntent: readOnlyIntent,
            authentication: authentication,
            connectTimeoutSeconds: connectTimeoutSeconds
        )

        let client = try await SQLServerClient.connect(
            configuration: config
        )

        // Wrap the SQLServerClient in an adapter that conforms to DatabaseSession
        return SQLServerSessionAdapter(
            client: client,
            configuration: config,
            database: resolvedDatabase?.isEmpty == false ? resolvedDatabase : nil
        )
    }
}
