import Foundation
import Logging
import PostgresNIO

public struct PostgresWireConfiguration: Sendable {
    public var host: String
    public var port: Int
    public var username: String
    public var password: String?
    public var database: String?
    public var useTLS: Bool
    public var applicationName: String?

    public init(
        host: String,
        port: Int = 5432,
        username: String,
        password: String?,
        database: String? = nil,
        useTLS: Bool = false,
        applicationName: String? = nil
    ) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.database = database
        self.useTLS = useTLS
        self.applicationName = applicationName
    }
}

public final class PostgresWireClient: @unchecked Sendable {
    private let client: PostgresClient
    private let runTask: Task<Void, Never>
    private let logger: Logger

    private init(client: PostgresClient, logger: Logger) {
        self.client = client
        self.logger = logger
        self.runTask = Task { await client.run() }
    }

    deinit {
        runTask.cancel()
    }

    public static func connect(
        configuration: PostgresWireConfiguration,
        logger: Logger = .init(label: "postgres-wire")
    ) async throws -> PostgresWireClient {
        let tls: PostgresClient.Configuration.TLS = configuration.useTLS
            ? .require(.makeClientConfiguration())
            : .disable

        let clientConfig = PostgresClient.Configuration(
            host: configuration.host,
            port: configuration.port,
            username: configuration.username,
            password: configuration.password,
            database: configuration.database ?? "postgres",
            tls: tls
        )
        // Some PostgresNIO versions may not support applicationName on client config; omit if unavailable.

        let client = PostgresClient(configuration: clientConfig, backgroundLogger: logger)
        let wire = PostgresWireClient(client: client, logger: logger)

        // Yield to ensure the client's run loop starts before first query.
        await Task.yield()
        do {
            _ = try await client.query("SELECT 1", logger: logger)
        } catch {
            wire.close()
            throw error
        }
        return wire
    }

    public func close() {
        runTask.cancel()
    }

    public func withConnection<T>(
        _ operation: (WireConnection) async throws -> T
    ) async throws -> T {
        try await client.withConnection { connection in
            try await operation(WireConnection(connection))
        }
    }

    public func query(_ query: WireQuery, logger: Logger? = nil) async throws -> WireRowSequence {
        try await client.query(query.asPostgresQuery(), logger: logger ?? self.logger)
    }
}
