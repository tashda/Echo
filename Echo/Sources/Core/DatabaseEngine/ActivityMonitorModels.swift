import Foundation
import SQLServerKit
import PostgresKit
import PostgresWire
import MySQLKit

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

public struct MySQLGlobalVariableInfo: Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let value: String
    public let category: String

    public init(name: String, value: String, category: String) {
        self.id = name.lowercased()
        self.name = name
        self.value = value
        self.category = category
    }
}

public struct MySQLActivitySnapshot: Sendable {
    public let capturedAt: Date
    public let processes: [MySQLProcessInfo]
    public let globalVariables: [MySQLGlobalVariableInfo]
    public let overview: MySQLActivityOverview?
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
    private let monitor: PostgresActivityClient

    public init(_ monitor: PostgresActivityClient) {
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

final class MySQLActivityMonitorWrapper: DatabaseActivityMonitoring {
    private let session: MySQLSession
    private actor SnapshotState {
        private var previousSample: MySQLActivityStatusSample?

        func buildSnapshot(
            capturedAt: Date,
            processes: [MySQLProcess],
            statusVariables: [MySQLStatusVariable],
            globalVariables: [MySQLGlobalVariable]
        ) -> MySQLActivitySnapshot {
            let result = MySQLActivitySnapshotBuilder.makeSnapshot(
                capturedAt: capturedAt,
                processes: processes,
                statusVariables: statusVariables,
                globalVariables: globalVariables,
                previousSample: previousSample
            )
            previousSample = result.sample
            return result.snapshot
        }
    }
    private let state = SnapshotState()

    init(session: MySQLSession) {
        self.session = session
    }

    func snapshot() async throws -> DatabaseActivitySnapshot {
        async let activitySnapshot = session.client.activity.snapshot()
        async let statusVariables = session.client.performance.dashboardStatus()
        async let globalVariables = session.client.serverConfig.globalVariables(named: nil)

        let capturedAt = Date()
        let typedSnapshot = try await state.buildSnapshot(
            capturedAt: capturedAt,
            processes: activitySnapshot.processes,
            statusVariables: statusVariables,
            globalVariables: globalVariables
        )
        return .mysql(typedSnapshot)
    }

    func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error> {
        return AsyncThrowingStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    do {
                        continuation.yield(try await snapshot())
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

    func killSession(id: Int) async throws {
        _ = try await session.client.query("KILL \(id)")
    }
}
