import Foundation
import Logging
import MySQLKit

struct MySQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dev.echodb.echo.mysql")

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
        hostNameInCertificate: String? = nil,
        readOnlyIntent: Bool = false,
        allowLegacyTLS: Bool = false,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        guard authentication.method == .sqlPassword else {
            throw DatabaseError.authenticationFailed("Windows authentication is not supported for MySQL")
        }
        let configuration = MySQLConfiguration(
            host: host,
            port: port,
            username: authentication.username,
            password: authentication.password,
            database: database,
            tlsMode: Self.tlsMode(enabled: tls, mode: tlsMode, caPath: sslRootCertPath),
            connectTimeoutSeconds: connectTimeoutSeconds,
            clientCertificatePath: sslCertPath,
            clientKeyPath: sslKeyPath
        )
        return MySQLSession(
            client: MySQLClient(configuration: configuration, logger: logger),
            configuration: configuration,
            logger: logger,
            defaultDatabase: database
        )
    }
}

extension MySQLNIOFactory {
    /// Echo's SSL mode in MySQL's terms. With TLS on and no mode chosen (MySQL's sheet has only a
    /// toggle today), Preferred: TLS when the server offers it, as before (Phase 7.3; the sheet's
    /// SSL Mode row and the default for new connections are Echo Labs round C).
    static func tlsMode(enabled: Bool, mode: TLSMode, caPath: String?) -> MySQLTLSMode {
        guard enabled else { return .disabled }
        let ca = caPath.flatMap { $0.isEmpty ? nil : $0 }
        switch mode {
        case .disable: return .disabled
        case .allow, .prefer: return .preferred
        case .require: return .required
        case .verifyCA: return ca.map { .verifyCA(caCertificatePath: $0) } ?? .verifyIdentity()
        case .verifyFull: return .verifyIdentity(caCertificatePath: ca)
        }
    }
}

final class MySQLSession: DatabaseSession {
    internal let client: MySQLClient
    internal let configuration: MySQLConfiguration
    internal let logger: Logger
    internal let defaultDatabase: String?
    internal let formatter = MySQLCellFormatter()

    init(
        client: MySQLClient,
        configuration: MySQLConfiguration,
        logger: Logger,
        defaultDatabase: String?
    ) {
        self.client = client
        self.configuration = configuration
        self.logger = logger
        self.defaultDatabase = defaultDatabase
    }

    func close() async {
        await client.close()
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        let effectiveDatabase = database.isEmpty ? nil : database
        var nextConfiguration = MySQLConfiguration(
            host: configuration.host,
            port: configuration.port,
            username: configuration.username,
            password: configuration.password,
            database: effectiveDatabase,
            tlsMode: configuration.tlsMode,
            connectTimeoutSeconds: configuration.connectTimeoutSeconds,
            keepAliveInterval: configuration.keepAliveInterval,
            clientCertificatePath: configuration.clientCertificatePath,
            clientKeyPath: configuration.clientKeyPath
        )
        nextConfiguration.clientKeyPassword = configuration.clientKeyPassword

        return MySQLSession(
            client: MySQLClient(configuration: nextConfiguration, logger: logger),
            configuration: nextConfiguration,
            logger: logger,
            defaultDatabase: effectiveDatabase
        )
    }
}
