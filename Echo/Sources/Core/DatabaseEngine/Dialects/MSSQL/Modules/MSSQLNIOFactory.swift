import Foundation
import SQLServerKit
import Logging

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
    private let logger = Logger(label: "dk.tippr.echo.mssql")

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
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        let resolvedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines)
        // Always login to master to avoid failures when the target database is offline.
        // The selected database is tracked separately in the session.
        let loginDatabase = "master"

        // Convert Echo authentication to SQLServerKit authentication
        let sqlServerAuth: SQLServerAuthentication

        switch authentication.method {
        case .sqlPassword:
            guard let password = authentication.password else {
                throw DatabaseError.authenticationFailed("Password is required for SQL authentication")
            }
            sqlServerAuth = SQLServerAuthentication.sqlPassword(
                username: authentication.username,
                password: password
            )
        case .windowsIntegrated:
            sqlServerAuth = SQLServerAuthentication.windowsIntegrated(
                username: authentication.username,
                password: authentication.password ?? "",
                domain: authentication.domain
            )
        case .accessToken:
            guard let token = authentication.password, !token.isEmpty else {
                throw DatabaseError.authenticationFailed("Access token is required for Entra ID authentication")
            }
            sqlServerAuth = SQLServerAuthentication.accessToken(token: token)
        }

        logger.info("Connecting to SQL Server at \(host):\(port)/\(loginDatabase)")

        let client = try await SQLServerClient.connect(
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

        // Wrap the SQLServerClient in an adapter that conforms to DatabaseSession
        return SQLServerSessionAdapter(
            client: client,
            database: resolvedDatabase?.isEmpty == false ? resolvedDatabase : nil
        )
    }
}
