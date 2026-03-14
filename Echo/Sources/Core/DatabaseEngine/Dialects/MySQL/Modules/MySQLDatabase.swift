import Foundation
import Logging
import MySQLNIO
import NIOCore
import NIOPosix
import NIOSSL

struct MySQLNIOFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.mysql")

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
        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let eventLoop = eventLoopGroup.any()
        let address = try SocketAddress.makeAddressResolvingHost(host, port: port)

        let tlsConfiguration = tls ? TLSConfiguration.makeClientConfiguration() : nil

        do {
            let connection = try await MySQLConnection.connect(
                to: address,
                username: authentication.username,
                database: database ?? "",
                password: authentication.password,
                tlsConfiguration: tlsConfiguration,
                serverHostname: tls ? host : nil,
                logger: logger,
                on: eventLoop
            ).get()

            if let database, !database.isEmpty {
                _ = try await connection.simpleQuery("USE `\(database.replacingOccurrences(of: "`", with: "``"))`").get()
            }

            return MySQLSession(
                connection: connection,
                eventLoopGroup: eventLoopGroup,
                logger: logger,
                defaultDatabase: database
            )
        } catch {
            try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                eventLoopGroup.shutdownGracefully { shutdownError in
                    if let shutdownError {
                        continuation.resume(throwing: shutdownError)
                    } else {
                        continuation.resume()
                    }
                }
            }
            throw DatabaseError.connectionFailed(error.localizedDescription)
        }
    }
}

final class MySQLSession: DatabaseSession {
    internal let connection: MySQLConnection
    internal let eventLoopGroup: MultiThreadedEventLoopGroup
    internal let logger: Logger
    internal let defaultDatabase: String?
    internal nonisolated(unsafe) let formatter = MySQLCellFormatter()

    private let shutdownQueue = DispatchQueue(label: "dk.tippr.echo.mysql.shutdown")
    private nonisolated(unsafe) var isClosed = false

    init(
        connection: MySQLConnection,
        eventLoopGroup: MultiThreadedEventLoopGroup,
        logger: Logger,
        defaultDatabase: String?
    ) {
        self.connection = connection
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        self.defaultDatabase = defaultDatabase
    }

    deinit {
        guard !isClosed else { return }
        isClosed = true

        let connection = self.connection
        let eventLoopGroup = self.eventLoopGroup
        let shutdownQueue = self.shutdownQueue
        let logger = self.logger

        connection.close().whenComplete { result in
            if case .failure(let error) = result {
                logger.warning("Failed to close MySQL connection during deinit: \(error.localizedDescription)")
            }

            eventLoopGroup.shutdownGracefully(queue: shutdownQueue) { shutdownError in
                if let shutdownError {
                    logger.warning("Failed to shut down MySQL event loop group during deinit: \(shutdownError.localizedDescription)")
                }
            }
        }
    }

    func close() async {
        guard !isClosed else { return }
        isClosed = true

        do {
            try await connection.close().get()
        } catch {
            logger.warning("Failed to close MySQL connection gracefully: \(error.localizedDescription)")
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            eventLoopGroup.shutdownGracefully(queue: shutdownQueue) { _ in
                continuation.resume()
            }
        }
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
}
