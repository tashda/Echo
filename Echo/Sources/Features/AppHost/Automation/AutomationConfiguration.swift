#if DEBUG
import Foundation

/// Test-server definitions and startup actions for an unattended Echo run.
/// Loaded from `~/.echo-automation/config.json` (never committed):
///
///     {
///       "connections": [
///         { "name": "Test MSSQL", "type": "mssql", "host": "192.168.1.234", "port": 14332,
///           "database": "", "username": "sa", "password": "...", "useTLS": false,
///           "trustServerCertificate": true },
///         { "name": "Test Postgres", "type": "postgresql", "host": "192.168.1.234", "port": 54322,
///           "database": "postgres", "username": "postgres", "password": "..." }
///       ],
///       "autoConnect": "Test MSSQL",
///       "openQueryTab": true
///     }
///
/// `type` is a `DatabaseType` raw value: `mssql`, `postgresql`, `mysql`, `sqlite`.
nonisolated struct AutomationConfiguration: Codable, Sendable {
    struct Connection: Codable, Sendable {
        var name: String
        var type: String
        var host: String
        var port: Int?
        var database: String?
        var username: String?
        var password: String?
        var useTLS: Bool?
        var trustServerCertificate: Bool?
    }

    var connections: [Connection]
    /// Name of the connection to open once the app has started.
    var autoConnect: String?
    /// Open an empty query tab after `autoConnect` succeeds.
    var openQueryTab: Bool?
}

nonisolated enum AutomationConfigurationLoader {
    static let launchArgument = "--automation"
    static let environmentKey = "ECHO_AUTOMATION"
    static let pathEnvironmentKey = "ECHO_AUTOMATION_CONFIG"

    static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".echo-automation/config.json")
    }

    /// Automation is opt-in per launch so ordinary debug runs never touch it.
    static var isRequested: Bool {
        let info = ProcessInfo.processInfo
        return info.arguments.contains(launchArgument) || info.environment[environmentKey] == "1"
    }

    static func load() throws -> AutomationConfiguration {
        let env = ProcessInfo.processInfo.environment
        let url = env[pathEnvironmentKey].map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) } ?? defaultURL
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AutomationConfiguration.self, from: data)
    }
}
#endif
