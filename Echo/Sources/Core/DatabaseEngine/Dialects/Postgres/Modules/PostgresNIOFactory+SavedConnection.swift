import Foundation
import PostgresKit
import os

/// PostgreSQL options the generic factory parameters don't carry (Echo Labs round 23): several
/// servers and Connect To (failover), Kerberos sign-in, and the client key's password.
extension PostgresNIOFactory {
    func connect(
        to connection: SavedConnection,
        database: String?,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) async throws -> DatabaseSession {
        let configuration = Self.makeConfiguration(
            for: connection, database: database, authentication: authentication, connectTimeoutSeconds: connectTimeoutSeconds)
        os.Logger.postgres.info("Connecting to PostgreSQL at \(connection.host):\(connection.port)/\(configuration.database) (\(connection.additionalHosts.count + 1) servers)")
        let serverConnection = try await PostgresServerConnection.connect(configuration: configuration, logger: packageLoggerForConnections)
        return PostgresSession(
            client: serverConnection.primaryClient,
            serverConnection: serverConnection,
            packageLogger: packageLoggerForConnections,
            databaseName: serverConnection.connectedDatabase
        )
    }

    /// The driver configuration for a saved connection. With Kerberos no password is sent; with
    /// Password, a server that asks for Kerberos still gets the ticket, as with libpq (round 23, PK1).
    static func makeConfiguration(
        for connection: SavedConnection,
        database: String?,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int
    ) -> PostgresConfiguration {
        var configuration = PostgresConfiguration(
            host: connection.host,
            port: connection.port,
            database: (database?.isEmpty == false ? database : nil) ?? "postgres",
            username: authentication.username,
            password: authentication.method == .kerberos ? nil : authentication.password,
            sslMode: connection.tlsMode.wireSSLMode,
            sslRootCertPath: connection.sslRootCertPath,
            sslCertPath: connection.sslCertPath,
            sslKeyPath: connection.sslCertPath.map(PostgresClientCertificate.isPKCS12) == true ? nil : connection.sslKeyPath,
            applicationName: "Echo",
            connectTimeout: connectTimeoutSeconds,
            additionalHosts: connection.additionalHosts.map { PostgresHost(host: $0.host, port: $0.port ?? connection.port) },
            targetSessionAttributes: connection.additionalHosts.isEmpty ? .any : connection.targetSessionAttributes.wireValue,
            loadBalanceHosts: connection.loadBalanceHosts && !connection.additionalHosts.isEmpty
        )
        configuration.sslKeyPassword = authentication.sslKeyPassword
        let service = connection.kerberosServiceName?.trimmingCharacters(in: .whitespaces) ?? ""
        configuration.kerberosServiceName = service.isEmpty ? "postgres" : service
        return configuration
    }
}

extension TLSMode {
    var wireSSLMode: PostgresSSLMode {
        switch self {
        case .disable: .disable
        case .allow: .allow
        case .prefer: .prefer
        case .require: .require
        case .verifyCA: .verifyCA
        case .verifyFull: .verifyFull
        }
    }
}

extension PostgresConnectTo {
    var wireValue: PostgresTargetSessionAttributes {
        switch self {
        case .any: .any
        case .primary: .primary
        case .standby: .standby
        case .preferStandby: .preferStandby
        case .readWrite: .readWrite
        case .readOnly: .readOnly
        }
    }
}
