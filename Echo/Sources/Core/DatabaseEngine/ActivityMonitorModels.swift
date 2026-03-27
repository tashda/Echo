import Foundation
import SQLServerKit
import PostgresKit
import PostgresWire

// MARK: - MySQL Process Info

public struct MySQLProcessInfo: Sendable, Identifiable, Hashable {
    public let id: Int
    public let user: String
    public let host: String
    public let database: String?
    public let command: String
    public let time: Int
    public let state: String?
    public let info: String?
}

public struct MySQLActivitySnapshot: Sendable {
    public let capturedAt: Date
    public let processes: [MySQLProcessInfo]
}

// MARK: - Snapshot Enum

public enum DatabaseActivitySnapshot: Sendable {
    case mssql(SQLServerActivitySnapshot)
    case postgres(PostgresActivitySnapshot)
    case mysql(MySQLActivitySnapshot)

    public var capturedAt: Date {
        switch self {
        case .mssql(let snap): return snap.capturedAt
        case .postgres(let snap): return snap.capturedAt
        case .mysql(let snap): return snap.capturedAt
        }
    }

    public var processes: [any Identifiable] {
        switch self {
        case .mssql(let snap): return snap.processes
        case .postgres(let snap): return snap.processes
        case .mysql(let snap): return snap.processes
        }
    }

    public var expensiveQueries: [any Identifiable] {
        switch self {
        case .mssql(let snap): return snap.expensiveQueries
        case .postgres(let snap): return snap.expensiveQueries
        case .mysql: return []
        }
    }
}

// MARK: - Protocol

public protocol DatabaseActivityMonitoring: Sendable {
    func snapshot() async throws -> DatabaseActivitySnapshot
    func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error>
    func killSession(id: Int) async throws
}

// MARK: - SQL Server Wrapper

public final class SQLServerActivityMonitorWrapper: DatabaseActivityMonitoring {
    private let monitor: SQLServerActivityMonitor

    public init(_ monitor: SQLServerActivityMonitor) {
        self.monitor = monitor
    }

    public func snapshot() async throws -> DatabaseActivitySnapshot {
        let snap = try await monitor.snapshot()
        return .mssql(snap)
    }

    public func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        let stream = monitor.streamSnapshots(every: seconds)
        return AsyncThrowingStream { continuation in
            let task = Task {
                for try await snap in stream {
                    continuation.yield(.mssql(snap))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func killSession(id: Int) async throws {
        try await monitor.killSession(sessionId: id)
    }
}

// MARK: - Postgres Wrapper

public final class PostgresActivityMonitorWrapper: DatabaseActivityMonitoring {
    private let monitor: PostgresAgentClient

    public init(_ monitor: PostgresAgentClient) {
        self.monitor = monitor
    }

    public func snapshot() async throws -> DatabaseActivitySnapshot {
        let snap = try await monitor.snapshot()
        return .postgres(snap)
    }

    public func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        let stream = monitor.streamSnapshots(every: seconds)
        return AsyncThrowingStream { continuation in
            let task = Task {
                for try await snap in stream {
                    continuation.yield(.postgres(snap))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func killSession(id: Int) async throws {
        try await monitor.killSession(pid: Int32(id))
    }
}

// MARK: - MySQL Monitor

public final class MySQLActivityMonitorWrapper: DatabaseActivityMonitoring {
    private let session: DatabaseSession

    public init(session: DatabaseSession) {
        self.session = session
    }

    public func snapshot() async throws -> DatabaseActivitySnapshot {
        let result = try await session.simpleQuery("SHOW PROCESSLIST")
        let processes = result.rows.compactMap { row -> MySQLProcessInfo? in
            guard row.count >= 8,
                  let idStr = row[0], let id = Int(idStr) else { return nil }
            return MySQLProcessInfo(
                id: id,
                user: row[1] ?? "",
                host: row[2] ?? "",
                database: row[3],
                command: row[4] ?? "",
                time: Int(row[5] ?? "0") ?? 0,
                state: row[6],
                info: row[7]
            )
        }
        return .mysql(MySQLActivitySnapshot(capturedAt: Date(), processes: processes))
    }

    public func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        let session = self.session
        return AsyncThrowingStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        let result = try await session.simpleQuery("SHOW PROCESSLIST")
                        let processes = result.rows.compactMap { row -> MySQLProcessInfo? in
                            guard row.count >= 8,
                                  let idStr = row[0], let id = Int(idStr) else { return nil }
                            return MySQLProcessInfo(
                                id: id,
                                user: row[1] ?? "",
                                host: row[2] ?? "",
                                database: row[3],
                                command: row[4] ?? "",
                                time: Int(row[5] ?? "0") ?? 0,
                                state: row[6],
                                info: row[7]
                            )
                        }
                        continuation.yield(.mysql(MySQLActivitySnapshot(capturedAt: Date(), processes: processes)))
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                    try? await Task.sleep(for: .seconds(seconds))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func killSession(id: Int) async throws {
        _ = try await session.simpleQuery("KILL \(id)")
    }
}
