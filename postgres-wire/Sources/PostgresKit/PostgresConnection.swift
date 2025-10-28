import Foundation
import Logging
import PostgresWire

public final class PostgresDatabaseConnection: @unchecked Sendable {
    private let wire: WireConnection
    private let logger: Logger
    private let cache: StatementCache
    private let serverCache: PreparedServerCache

    init(wireConnection: WireConnection, logger: Logger, cache: StatementCache, serverCache: PreparedServerCache) {
        self.wire = wireConnection
        self.logger = logger
        self.cache = cache
        self.serverCache = serverCache
    }

    @discardableResult
    public func simpleQuery(_ sql: String) async throws -> WireRowSequence {
        try await wire.query(WireQuery(sql: sql), logger: logger)
    }

    public func query(_ sql: String, binds: [PGData] = []) async throws -> WireRowSequence {
        if binds.isEmpty {
            return try await wire.query(WireQuery(sql: sql), logger: logger)
        }
        let paramCount = binds.count
        if let info = cache.lookup(sql: sql, parameterCount: paramCount) {
            do {
                return try await wire.execute(prepared: info.handle, binds: binds, logger: logger)
            } catch let err as PSQLError {
                if let state = err.serverInfo?[.sqlState], state == "26000" {
                    // invalid_sql_statement_name -> evict and retry once
                    cache.remove(sql: sql, parameterCount: paramCount)
                    let prepared = try await wire.prepare(sql)
                    let info = PreparedStatementInfo(sql: sql, parameterCount: paramCount, handle: prepared)
                    cache.insert(info)
                    return try await wire.execute(prepared: prepared, binds: binds, logger: logger)
                }
                throw err
            }
        } else {
            let prepared = try await wire.prepare(sql)
            let info = PreparedStatementInfo(sql: sql, parameterCount: paramCount, handle: prepared)
            cache.insert(info)
            return try await wire.execute(prepared: prepared, binds: binds, logger: logger)
        }
    }

    // MARK: - Notifications

    @discardableResult
    public func addNotificationListener(
        channel: String,
        handler: @escaping @Sendable (PostgresNotification) -> Void
    ) -> WireConnection.WireListenToken {
        wire.addNotificationListener(channel: channel) { channel, payload, pid in
            handler(PostgresNotification(channel: channel, payload: payload, pid: pid))
        }
    }

    public func waitForClose() async {
        await wire.waitForClose()
    }

    // Optional server-side prepared execution that returns all rows in memory.
    // Uses a per-connection server prepare cache keyed by SQL + parameter OIDs.
    public func queryPreparedRows(_ sql: String, binds: [PGData] = []) async throws -> [PostgresRow] {
        let types = binds.map { $0.type }
        let key = ServerPrepareKey.make(sql: sql, types: types)
        if let prepared = await serverCache.lookup(key) {
            do {
                return try await wire.executePreparedRows(prepared, binds: binds)
            } catch let err as PSQLError {
                if let state = err.serverInfo?[.sqlState], state == "26000" {
                    await serverCache.remove(key)
                    let fresh = try await wire.prepareQuery(sql)
                    await serverCache.insert(key, prepared: fresh)
                    return try await wire.executePreparedRows(fresh, binds: binds)
                }
                throw err
            }
        } else {
            let prepared = try await wire.prepareQuery(sql)
            await serverCache.insert(key, prepared: prepared)
            return try await wire.executePreparedRows(prepared, binds: binds)
        }
    }
}
