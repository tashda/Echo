import Foundation
import Logging
import PostgresNIO

// MARK: - Query & Row Types

public struct WireQuery: Sendable {
    public let sql: String
    public let binds: PostgresBindings?

    public init(sql: String, binds: PostgresBindings? = nil) {
        self.sql = sql
        self.binds = binds
    }

    public func asPostgresQuery() -> PostgresQuery {
        if let binds {
            return PostgresQuery(unsafeSQL: sql, binds: binds)
        } else {
            return PostgresQuery(unsafeSQL: sql)
        }
    }
}

public typealias WireRowSequence = PostgresRowSequence

// Re-export PostgresNIO types so higher layers can rely only on PostgresWire.
public typealias PostgresRowSequence = PostgresNIO.PostgresRowSequence
public typealias PostgresError = PostgresNIO.PostgresError
public typealias PostgresDataType = PostgresNIO.PostgresDataType
public typealias PostgresFormat = PostgresNIO.PostgresFormat
public typealias PostgresCell = PostgresNIO.PostgresCell
public typealias PostgresData = PostgresNIO.PostgresData
public typealias PostgresBindings = PostgresNIO.PostgresBindings
public typealias PostgresListenContext = PostgresNIO.PostgresListenContext
public typealias WirePreparedQuery = PostgresNIO.PreparedQuery

// Re-export select low-level types so higher layers don't import PostgresNIO.
public typealias PGData = PostgresData
public typealias PGBindings = PostgresBindings

// MARK: - Connection Protocol

public protocol WireConnectionProtocol: Sendable {
    func query(_ query: WireQuery, logger: Logger?) async throws -> WireRowSequence
}

// MARK: - Execution Options (forward-compatible)

public enum WireExecutionMode: Sendable, Equatable {
    case auto
    case simple
    case cursor
}

public struct WireQueryOptions: Sendable, Equatable {
    public var mode: WireExecutionMode
    public var cursorThreshold: Int?

    public init(mode: WireExecutionMode = .auto, cursorThreshold: Int? = nil) {
        self.mode = mode
        self.cursorThreshold = cursorThreshold
    }
}

// MARK: - Wire Connection Wrapper

public final class WireConnection: WireConnectionProtocol {
    private let connection: PostgresConnection

    public init(_ connection: PostgresConnection) {
        self.connection = connection
    }

    public func query(_ query: WireQuery, logger: Logger?) async throws -> WireRowSequence {
        let log = logger ?? Logger(label: "postgres-wire")
        return try await connection.query(query.asPostgresQuery(), logger: log)
    }

    /// Experimental overload that accepts execution options. For now, it forwards to simple execution.
    /// Higher layers (e.g., Echo) currently implement cursor/simple selection. This is here to
    /// provide a stable surface for future enhancements in the wire package.
    public func query(_ query: WireQuery, options: WireQueryOptions?, logger: Logger?) async throws -> WireRowSequence {
        try await self.query(query, logger: logger)
    }

    public var id: ObjectIdentifier { ObjectIdentifier(connection) }

    // MARK: - Notifications

    public struct WireListenToken: Sendable {
        private let context: PostgresListenContext
        private let channel: String
        init(context: PostgresListenContext, channel: String) {
            self.context = context
            self.channel = channel
        }
        public func stop() {
            context.stop()
        }
    }

    /// Register a notification listener for a channel. Caller is responsible for issuing LISTEN/UNLISTEN.
    /// The returned token can be used to stop the listener.
    @discardableResult
    public func addNotificationListener(
        channel: String,
        _ handler: @escaping @Sendable (_ channel: String, _ payload: String, _ pid: Int32) -> Void
    ) -> WireListenToken {
        let ctx = connection.addListener(channel: channel) { _, message in
            handler(message.channel, message.payload, message.backendPID)
        }
        return WireListenToken(context: ctx, channel: channel)
    }

    /// Suspend until the underlying connection closes.
    public func waitForClose() async {
        _ = try? await connection.closeFuture.get()
    }

    // MARK: - Server-side prepare helpers (array results)
    public func prepareAndExecuteRows(sql: String, binds: [PGData], logger: Logger?) async throws -> [PostgresRow] {
        let prepared = try await connection.prepare(query: sql).get()
        return try await prepared.execute(binds).get()
    }

    // Prepared statement scaffolding: can be upgraded to real server-side prepare later.
    public struct WirePreparedStatement: Sendable {
        public let sql: String
        public init(sql: String) { self.sql = sql }
    }

    public func prepare(_ sql: String) async throws -> WirePreparedStatement {
        WirePreparedStatement(sql: sql)
    }

    public func execute(prepared: WirePreparedStatement, binds: [PGData], logger: Logger?) async throws -> WireRowSequence {
        var bindings = PGBindings()
        for b in binds { bindings.append(b) }
        let q = WireQuery(sql: prepared.sql, binds: bindings)
        return try await query(q, logger: logger)
    }

    public func close(_ prepared: WirePreparedStatement) async {}

    // MARK: - Server-side prepares (helpers)
    public func prepareQuery(_ sql: String) async throws -> WirePreparedQuery {
        try await connection.prepare(query: sql).get()
    }

    public func executePreparedRows(_ prepared: WirePreparedQuery, binds: [PGData]) async throws -> [PostgresRow] {
        try await prepared.execute(binds).get()
    }

    public func deallocate(_ prepared: WirePreparedQuery) async {
        _ = try? await prepared.deallocate().get()
    }
}
