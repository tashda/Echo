import Foundation
import Logging
import Metrics
import PostgresWire

public final class PostgresDatabaseClient: @unchecked Sendable {
    private let wire: PostgresWireClient
    private let logger: Logger
    private let registry = PreparedRegistry()

    private init(wire: PostgresWireClient, logger: Logger) {
        self.wire = wire
        var logger = logger
        logger[metadataKey: "component"] = "PostgresDatabaseClient"
        self.logger = logger
    }

    deinit { wire.close() }

    public static func connect(
        configuration: PostgresConfiguration,
        logger: Logger = .init(label: "postgres-kit")
    ) async throws -> PostgresDatabaseClient {
        let wire = try await PostgresWireClient.connect(configuration: configuration.makeWireConfiguration(), logger: logger)
        return PostgresDatabaseClient(wire: wire, logger: logger)
    }

    public func close() { wire.close() }

    // Simple convenience query on pooled client.
    public func simpleQuery(_ sql: String) async throws -> WireRowSequence {
        try await wire.query(WireQuery(sql: sql), logger: logger)
    }

    // Borrow a single connection for multi-step operations.
    public func withConnection<T>(
        _ body: @Sendable (PostgresDatabaseConnection) async throws -> T
    ) async throws -> T {
        try await wire.withConnection { connection in
            let cache = await registry.statementCache(for: connection.id)
            let serverCache = await registry.serverPreparedCache(for: connection.id)
            return try await body(PostgresDatabaseConnection(wireConnection: connection, logger: logger, cache: cache, serverCache: serverCache))
        }
    }
}

// Registry associates a per-connection StatementCache via connection identity.
private actor PreparedRegistry {
    private var stmtCaches: [ObjectIdentifier: StatementCache] = [:]
    private var serverCaches: [ObjectIdentifier: PreparedServerCache] = [:]

    func statementCache(for id: ObjectIdentifier) -> StatementCache {
        if let cache = stmtCaches[id] { return cache }
        let new = StatementCache(capacity: 256)
        stmtCaches[id] = new
        return new
    }

    func serverPreparedCache(for id: ObjectIdentifier) -> PreparedServerCache {
        if let cache = serverCaches[id] { return cache }
        let new = PreparedServerCache(capacity: 128)
        serverCaches[id] = new
        return new
    }
}
