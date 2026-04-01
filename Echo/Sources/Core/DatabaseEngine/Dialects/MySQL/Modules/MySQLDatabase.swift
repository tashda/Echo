import Foundation
import Logging
import MySQLKit
import MySQLWire

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
        readOnlyIntent: Bool = false,
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
            useTLS: tls && tlsMode != .disable,
            connectTimeoutSeconds: connectTimeoutSeconds
        )

        return MySQLSession(
            client: MySQLClient(configuration: configuration, logger: logger),
            configuration: configuration,
            logger: logger,
            defaultDatabase: database
        )
    }
}

final class MySQLSession: DatabaseSession {
    internal let client: MySQLClient
    internal let configuration: MySQLConfiguration
    internal let logger: Logger
    internal let defaultDatabase: String?
    internal nonisolated(unsafe) let formatter = MySQLCellFormatter()

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

    internal func rawCellData(from buffer: ByteBuffer?) -> Data? {
        guard var buffer else { return nil }
        let readable = buffer.readableBytes
        guard readable > 0 else { return Data() }
        guard let bytes = buffer.readBytes(length: readable) else { return nil }
        return Data(bytes)
    }

    internal func makeString(_ row: MySQLRow, index: Int) -> String? {
        guard row.values.indices.contains(index) else { return nil }
        let definition = row.columnDefinitions[index]
        let data = MySQLData(
            type: definition.columnType,
            format: row.format,
            buffer: row.values[index],
            isUnsigned: definition.flags.contains(.COLUMN_UNSIGNED)
        )
        return formatter.stringValue(for: data)
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        let effectiveDatabase = database.isEmpty ? nil : database
        let nextConfiguration = MySQLConfiguration(
            host: configuration.host,
            port: configuration.port,
            username: configuration.username,
            password: configuration.password,
            database: effectiveDatabase,
            useTLS: configuration.useTLS,
            connectTimeoutSeconds: configuration.connectTimeoutSeconds,
            keepAliveInterval: configuration.keepAliveInterval
        )

        return MySQLSession(
            client: MySQLClient(configuration: nextConfiguration, logger: logger),
            configuration: nextConfiguration,
            logger: logger,
            defaultDatabase: effectiveDatabase
        )
    }
}
