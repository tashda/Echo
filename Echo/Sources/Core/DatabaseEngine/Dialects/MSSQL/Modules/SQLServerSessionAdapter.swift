import Foundation
import SQLServerKit
import Logging

/// Serializes metadata trace file writes to avoid data races
private actor MetadataTraceWriter {
    func append(_ data: Data, to path: String) {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                handle.seekToEndOfFile()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Adapter to make SQLServerClient conform to Echo's DatabaseSession protocol
final class SQLServerSessionAdapter: DatabaseSession, MSSQLSession {
    let client: SQLServerClient
    let database: String?
    let logger = Logger(label: "dk.tippr.echo.mssql.metadata")
    let metadataTraceEnabled = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE"] == "1"
    let metadataTracePath: String?
    private static let traceWriter = MetadataTraceWriter()

    init(client: SQLServerClient, database: String?) {
        self.client = client
        self.database = database
        if metadataTraceEnabled {
            let envPath = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE_PATH"]
            metadataTracePath = envPath?.isEmpty == false ? envPath : "/tmp/echo-mssql-metadata-trace.log"
        } else {
            metadataTracePath = nil
        }
    }

    func close() async {
        do {
            try await client.close()
        } catch {
            // Ignore shutdown errors; the app is shutting down the session.
        }
    }

    func metadataTrace(_ line: String) {
        guard metadataTraceEnabled else { return }
        logger.info("\(line)")
        print(line)
        guard let path = metadataTracePath else { return }
        let payload = line + "\n"
        guard let data = payload.data(using: .utf8) else { return }
        Task {
            await Self.traceWriter.append(data, to: path)
        }
    }

    func metadataTimed<T>(_ label: String, operation: () async throws -> T) async throws -> T {
        guard metadataTraceEnabled else {
            return try await operation()
        }
        let started = Date()
        let result = try await operation()
        let elapsed = String(format: "%.3f", Date().timeIntervalSince(started))
        metadataTrace("[MSSQLMetadataTrace] step \(label) \(elapsed)s")
        return result
    }

    // MARK: - MSSQLSession

    func serverVersion() async throws -> String {
        try await client.serverVersion()
    }

    var metadata: SQLServerMetadataNamespace { client.metadata }
    var agent: SQLServerAgentOperations { client.agent }
    var admin: SQLServerAdministrationClient { client.admin }
    var security: SQLServerSecurityClient { client.security }
    var serverSecurity: SQLServerServerSecurityClient { client.serverSecurity }

    func rebuildIndex(schema: String, table: String, index: String) async throws {
        try await client.indexes.rebuildIndex(name: index, table: table, schema: schema)
    }

    func sessionForDatabase(_ database: String) async throws -> DatabaseSession {
        _ = try await client.execute("USE [\(database.replacingOccurrences(of: "]", with: "]]"))]")
        return self
    }

    func makeActivityMonitor() throws -> any DatabaseActivityMonitoring {
        SQLServerActivityMonitorWrapper(client.activity)
    }
}
