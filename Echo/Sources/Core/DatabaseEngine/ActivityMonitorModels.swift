import Foundation
import SQLServerKit
import PostgresKit
import PostgresWire

public enum DatabaseActivitySnapshot: Sendable {
    case mssql(SQLServerActivitySnapshot)
    case postgres(PostgresActivitySnapshot)
    
    public var capturedAt: Date {
        switch self {
        case .mssql(let snap): return snap.capturedAt
        case .postgres(let snap): return snap.capturedAt
        }
    }

    public var processes: [any Identifiable] {
        switch self {
        case .mssql(let snap): return snap.processes
        case .postgres(let snap): return snap.processes
        }
    }

    public var expensiveQueries: [any Identifiable] {
        switch self {
        case .mssql(let snap): return snap.expensiveQueries
        case .postgres(let snap): return snap.expensiveQueries
        }
    }
}

public protocol DatabaseActivityMonitoring: Sendable {
    func snapshot() async throws -> DatabaseActivitySnapshot
    func streamSnapshots(every seconds: TimeInterval) -> AsyncThrowingStream<DatabaseActivitySnapshot, Error>
    func killSession(id: Int) async throws
}

// Wrapper for SQL Server
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

// Wrapper for Postgres
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
