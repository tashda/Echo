import Foundation
import SQLServerKit
import Logging

/// Adapter to make SQLServerClient conform to Echo's DatabaseSession protocol
final class SQLServerSessionAdapter: DatabaseSession, MSSQLSession {
    let client: SQLServerClient
    let database: String?
    let logger = Logger(label: "dk.tippr.echo.mssql.metadata")
    let metadataTraceEnabled = ProcessInfo.processInfo.environment["MSSQL_METADATA_TRACE"] == "1"
    let metadataTracePath: String?
    static let metadataTraceQueue = DispatchQueue(label: "dk.tippr.echo.mssql.metadata.trace")

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
            try await client.shutdownGracefully().get()
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
        Self.metadataTraceQueue.async {
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

    func makeAgentClient() -> SQLServerAgentClient {
        SQLServerAgentClient(client: client)
    }

    func makeDatabaseSecurityClient() -> SQLServerDatabaseSecurityClient {
        SQLServerDatabaseSecurityClient(client: client)
    }

    func makeServerSecurityClient() -> SQLServerServerSecurityClient {
        SQLServerServerSecurityClient(client: client)
    }

    func makeAdministrationClient() -> SQLServerAdministrationClient {
        SQLServerAdministrationClient(client: client)
    }
}
