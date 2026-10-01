import Foundation

extension PostgresBackupRestoreViewModel {
    func splitPatterns(_ input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    func buildConnectionURI(database: String) -> String {
        let sslmode = "prefer"
        let host = connection.host.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? connection.host
        let effectiveUsername = resolvedUsername ?? connection.username
        let user = effectiveUsername.addingPercentEncoding(withAllowedCharacters: .urlUserAllowed) ?? effectiveUsername
        let db = database.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? database

        var userInfo = user
        if let password = connectionPassword, !password.isEmpty {
            let encodedPassword = password.addingPercentEncoding(withAllowedCharacters: .urlPasswordAllowed) ?? password
            userInfo = "\(user):\(encodedPassword)"
        }

        return "postgresql://\(userInfo)@\(host):\(connection.port)/\(db)?sslmode=\(sslmode)"
    }

    func buildEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let password = connectionPassword, !password.isEmpty {
            env["PGPASSWORD"] = password
        }
        env["PGSSLMODE"] = connection.useTLS ? "require" : "disable"
        // libpq tries GSS encryption first whenever a Kerberos ticket exists; only Kerberos
        // sign-ins should. The bundled tools find libpq through their rpath, no DYLD_ needed.
        env["PGGSSENCMODE"] = connection.authenticationMethod == .kerberos ? "prefer" : "disable"
        return env
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
