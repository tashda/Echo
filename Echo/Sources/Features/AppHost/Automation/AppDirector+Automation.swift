#if DEBUG
import Foundation
import OSLog

extension AppDirector {
    private static let automationLogger = Logger(subsystem: "dev.echodb.echo", category: "automation")

    /// Registers the configured test servers in memory and optionally connects.
    /// Does nothing unless the app was launched with `--automation` (or `ECHO_AUTOMATION=1`).
    func runAutomationIfRequested() async {
        guard AutomationConfigurationLoader.isRequested else { return }
        let logger = Self.automationLogger

        let configuration: AutomationConfiguration
        do {
            configuration = try AutomationConfigurationLoader.load()
        } catch {
            logger.error("Automation config could not be loaded: \(error.localizedDescription, privacy: .public)")
            return
        }

        let projectID = projectStore.selectedProject?.id
        var registered: [String: SavedConnection] = [:]
        for entry in configuration.connections {
            guard var connection = automationConnection(from: entry, projectID: projectID) else {
                logger.error("Skipping \(entry.name, privacy: .public): unknown type \(entry.type, privacy: .public)")
                continue
            }
            if let password = entry.password {
                do {
                    try identityRepository.setPassword(password, for: &connection)
                } catch {
                    logger.error("Keychain write failed for \(entry.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
            // In memory only: never call `saveConnections()`, so the user's saved list is untouched.
            connectionStore.connections.removeAll { $0.id == connection.id }
            connectionStore.connections.append(connection)
            registered[entry.name] = connection
            logger.info("Registered automation connection \(entry.name, privacy: .public)")
        }

        if let script = AutomationScript.load() {
            // Its own task, so a long script never holds up the app finishing its start.
            Task(name: "automation-script") { await self.runAutomationScript(script, connections: registered) }
            return
        }

        guard let name = configuration.autoConnect, let target = registered[name] else { return }
        environmentState.connect(to: target)
        logger.info("Automation connecting to \(name, privacy: .public)")

        if configuration.openQueryTab == true {
            await openAutomationQueryTab(for: target)
        }
    }

    private func openAutomationQueryTab(for connection: SavedConnection) async {
        // Wait for the session to come up (up to 30s) before opening the tab.
        for _ in 0..<60 {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id) {
                environmentState.openQueryTab(for: session)
                Self.automationLogger.info("Automation opened query tab")
                return
            }
            try? await Task.sleep(for: .milliseconds(500))
        }
        Self.automationLogger.error("Automation timed out waiting for \(connection.connectionName, privacy: .public)")
    }

    private func automationConnection(from entry: AutomationConfiguration.Connection, projectID: UUID?) -> SavedConnection? {
        guard let type = DatabaseType(rawValue: entry.type) else { return nil }
        return SavedConnection(
            id: Self.automationConnectionID(for: entry.name),
            projectID: projectID,
            connectionName: entry.name,
            host: entry.host,
            port: entry.port ?? type.defaultPort,
            database: entry.database ?? "",
            username: entry.username ?? "",
            useTLS: entry.useTLS ?? false,
            trustServerCertificate: entry.trustServerCertificate ?? true,
            databaseType: type
        )
    }

    /// Stable per name so repeated runs replace rather than duplicate, and the keychain item is reused.
    private static func automationConnectionID(for name: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        for (index, byte) in Array("echo.automation.\(name)".utf8).enumerated() {
            bytes[index % 16] = bytes[index % 16] &+ byte &* UInt8(truncatingIfNeeded: index + 1)
        }
        return UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                           bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
    }
}
#endif
