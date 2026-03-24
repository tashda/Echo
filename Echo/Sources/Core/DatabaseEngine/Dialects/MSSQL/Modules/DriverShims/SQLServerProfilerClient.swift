import SQLServerKit
import Foundation
import NIO

/// Namespace client for high-frequency SQL event tracing (SQL Profiler).
///
/// This client provides a unified interface for tracing SQL Server events, mapping
/// legacy SQL Profiler events to modern Extended Events (XE) under the hood.
public final class SQLServerProfilerClient: @unchecked Sendable {
    private let client: SQLServerClient

    internal init(client: SQLServerClient) {
        self.client = client
    }

    // MARK: - Trace Control

    /// Creates and starts a live trace session for the specified events.
    ///
    /// - Parameters:
    ///   - sessionName: Name for the Extended Events session.
    ///   - events: List of classic SQL Trace events to capture.
    ///   - targetDatabase: Optional filter to only capture events for a specific database.
    @available(macOS 12.0, *)
    public func startLiveTrace(
        name sessionName: String,
        events: [SQLTraceEvent],
        targetDatabase: String? = nil
    ) async throws {
        var actions = ["sqlserver.client_app_name", "sqlserver.client_hostname", "sqlserver.database_name", "sqlserver.session_id", "sqlserver.sql_text", "sqlserver.username"]
        
        var predicate: String? = nil
        if let db = targetDatabase {
            let escapedDB = db.replacingOccurrences(of: "'", with: "''")
            predicate = "sqlserver.database_name = N'\(escapedDB)'"
        }
        
        let eventSpecs = events.map { event in
            SQLServerXESessionConfiguration.EventSpec(
                eventName: "sqlserver.\(event.xeEventName)",
                actions: actions,
                predicate: predicate
            )
        }
        
        let config = SQLServerXESessionConfiguration(
            name: sessionName,
            events: eventSpecs,
            target: .ringBuffer(maxMemoryKB: 8192),
            maxMemoryKB: 8192,
            startupState: false
        )
        
        try await client.extendedEvents.createSession(config)
        try await client.extendedEvents.startSession(name: sessionName)
    }

    /// Stops and deletes a trace session.
    @available(macOS 12.0, *)
    public func stopLiveTrace(name sessionName: String) async throws {
        try await client.extendedEvents.dropSession(name: sessionName)
    }

    // MARK: - Data Retrieval

    /// Reads captured trace events from the live session's ring buffer.
    @available(macOS 12.0, *)
    public func readTraceEvents(sessionName: String, maxEvents: Int = 500) async throws -> [SQLServerProfilerEvent] {
        let xeData = try await client.extendedEvents.readRingBufferData(sessionName: sessionName, maxEvents: maxEvents)
        
        return xeData.map { data in
            SQLServerProfilerEvent(
                eventName: data.eventName,
                timestamp: data.timestamp,
                textData: data.fields["batch_text"] ?? data.fields["statement"] ?? data.fields["sql_text"],
                databaseName: data.fields["database_name"],
                loginName: data.fields["username"] ?? data.fields["nt_username"],
                duration: Int64(data.fields["duration"] ?? "0"),
                cpu: Int(data.fields["cpu_time"] ?? "0"),
                reads: Int64(data.fields["logical_reads"] ?? "0"),
                writes: Int64(data.fields["writes"] ?? "0"),
                spid: Int(data.fields["session_id"] ?? "0")
            )
        }
    }
}
