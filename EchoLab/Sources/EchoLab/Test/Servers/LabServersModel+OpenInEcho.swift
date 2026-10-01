import AppKit
import Foundation
import ServerLabKit

/// Launches a Debug build of Echo already connected to a started server, through Echo's
/// automation mode (`--automation`, `ECHO_AUTOMATION_CONFIG`; see `AutomationConfiguration.swift`).
extension LabServersModel {
    /// The newest Debug build of Echo on this Mac (Xcode's or XcodeBuildMCP's DerivedData), or nil.
    static var debugEchoApp: URL? {
        let developer = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library/Developer")
        var candidates: [URL] = []
        for root in ["Xcode/DerivedData", "XcodeBuildMCP"] {
            let folder = developer.appending(path: root)
            for entry in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
                candidates.append(folder.appending(path: "\(entry)/Build/Products/Debug/Echo.app"))
            }
        }
        return candidates
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { modified($0) < modified($1) }
    }

    /// Why Echo cannot connect to this server through automation mode, or nil when it can.
    static func openInEchoLimitation(_ server: LabDatabaseServer) -> String? {
        if server.kerberos != nil { return "Kerberos logins are not in Echo's automation settings" }
        if server.tls?.clientCertificatePath != nil { return "Client-certificate logins are not in Echo's automation settings" }
        return nil
    }

    func openInEcho(_ server: LabDatabaseServer) {
        guard let app = Self.debugEchoApp else {
            append("No Debug build of Echo found: build Echo in Xcode first")
            return
        }
        do {
            let file = try Self.writeAutomationConfiguration(for: server)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--automation"]
            configuration.environment = ["ECHO_AUTOMATION": "1", "ECHO_AUTOMATION_CONFIG": file.path]
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: app, configuration: configuration) { _, error in
                Task { @MainActor in
                    self.append(error.map { "Echo did not start: \($0.localizedDescription)" }
                                ?? "Opened \(server.containerName) in Echo (\(app.path))")
                }
            }
            // The file holds the lab password; Echo reads it at launch.
            Task {
                try? await Task.sleep(for: .seconds(60))
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            append("Open in Echo failed: \(error.localizedDescription)")
        }
    }

    /// Echo's automation settings for one connection to `server`, in a file only the user can read.
    static func writeAutomationConfiguration(for server: LabDatabaseServer) throws -> URL {
        let name = "Lab \(server.recipe)"
        let type = switch server.engine {
        case .sqlServer: "mssql"
        case .postgres: "postgresql"
        case .mysql, .mariadb: "mysql"
        }
        var connection: [String: Any] = [
            "name": name, "type": type, "host": server.host, "port": server.port,
            "username": server.username, "password": server.password,
            // SQL Server encrypts the login; lab certificates are self-signed or from the lab CA.
            "useTLS": server.engine == .sqlServer || server.tls != nil, "trustServerCertificate": true,
        ]
        if server.engine == .postgres { connection["database"] = "postgres" }
        let settings: [String: Any] = ["connections": [connection], "autoConnect": name, "openQueryTab": true]
        let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".echo-testlab/automation")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = folder.appending(path: "\(server.containerName).json")
        try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return file
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
