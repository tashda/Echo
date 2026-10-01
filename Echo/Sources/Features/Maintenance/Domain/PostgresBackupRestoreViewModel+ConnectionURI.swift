import Foundation
import PostgresKit

extension PostgresBackupRestoreViewModel {
    func splitPatterns(_ input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// How the tools reach the server for `database`, as this session's connection does: hosts,
    /// TLS mode and files, Kerberos, the password only in the environment (#34). Keep it until the
    /// tool has finished.
    func toolConnection(database: String) async throws -> PostgresToolConnection {
        if let postgres = session as? PostgresSession {
            return try await postgres.client.toolConnection(database: database)
        }
        return try await PostgresToolConnection.make(
            for: connection, database: database,
            authentication: DatabaseAuthenticationConfiguration(
                method: connection.authenticationMethod, username: resolvedUsername ?? connection.username, password: connectionPassword
            )
        )
    }

    func detectFormat() {
        guard let url = inputURL else { return }
        let ext = url.pathExtension.lowercased()
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        if isDir.boolValue {
            detectedFormat = .directory
        } else if ext == "sql" {
            detectedFormat = .plain
        } else if ext == "tar" {
            detectedFormat = .tar
        } else {
            detectedFormat = .custom
        }
    }

    func isPlainSQL(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "sql" { return true }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { handle.closeFile() }
        guard let data = try? handle.read(upToCount: 32) else { return false }
        guard let header = String(data: data, encoding: .utf8) else { return false }
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("--") || trimmed.hasPrefix("CREATE") || trimmed.hasPrefix("SET")
    }
}
