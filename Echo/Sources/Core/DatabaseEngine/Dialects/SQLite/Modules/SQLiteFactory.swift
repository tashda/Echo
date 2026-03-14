import Foundation
import Logging
import SQLiteNIO
import NIOCore

struct SQLiteFactory: DatabaseFactory {
    private let logger = Logger(label: "dk.tippr.echo.sqlite")

    func connect(
        host: String,
        port: Int,
        database: String?,
        tls: Bool,
        trustServerCertificate: Bool = false,
        tlsMode: TLSMode = .prefer,
        sslRootCertPath: String? = nil,
        sslCertPath: String? = nil,
        sslKeyPath: String? = nil,
        mssqlEncryptionMode: MSSQLEncryptionMode = .optional,
        readOnlyIntent: Bool = false,
        authentication: DatabaseAuthenticationConfiguration,
        connectTimeoutSeconds: Int = 10
    ) async throws -> DatabaseSession {
        _ = authentication
        let resolvedPath = try resolveDatabasePath(host: host, database: database)
        do {
            let storage: SQLiteConnection.Storage = resolvedPath == ":memory:"
                ? .memory
                : .file(path: resolvedPath)
            let connection = try await SQLiteConnection.open(storage: storage, logger: logger)
            let session = SQLiteSession(logger: logger)
            await session.bootstrap(with: connection)
            return session
        } catch {
            throw DatabaseError.connectionFailed("Failed to open SQLite database: \(error.localizedDescription)")
        }
    }

    private func resolveDatabasePath(host: String, database: String?) throws -> String {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDatabase = database?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var candidate = trimmedHost
        if candidate.isEmpty {
            candidate = trimmedDatabase
        }

        guard !candidate.isEmpty else {
            throw DatabaseError.connectionFailed("A database file path is required for SQLite connections")
        }

        if candidate == ":memory:" {
            return candidate
        }

        if candidate.hasPrefix("file:") {
            return candidate
        }

        let expanded = (candidate as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return expanded
        }

        let absolute = URL(fileURLWithPath: expanded, relativeTo: FileManager.default.currentDirectoryPathURL).path
        return absolute
    }
}

private extension FileManager {
    var currentDirectoryPathURL: URL {
        URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
}
