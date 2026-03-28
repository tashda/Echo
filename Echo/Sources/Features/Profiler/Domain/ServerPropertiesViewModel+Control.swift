import Foundation
import MySQLKit
import MySQLWire

extension ServerPropertiesViewModel {
    var isLocalMySQLHost: Bool {
        guard let mysql = session as? MySQLSession else { return false }
        let host = mysql.configuration.host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host.isEmpty || host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    func refreshServerControlState(mysql: MySQLSession) async {
        guard isLocalMySQLHost else {
            serverControlState = .unavailable("Server control is only available for local MySQL instances.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            try await withTemporaryClient(for: mysql) { client in
                _ = try await client.admin.globalStatus(named: "Uptime")
            }
            serverControlState = .running
        } catch {
            serverControlState = .stopped
        }
    }

    func stopLocalMySQLServer(customToolPath: String?) async {
        guard let mysql = session as? MySQLSession else { return }
        guard isLocalMySQLHost else {
            serverControlState = .unavailable("Server control is only available for local MySQL instances.")
            return
        }
        guard let mysqladmin = MySQLToolLocator.mysqladminURL(customPath: customToolPath) else {
            serverControlState = .unavailable("mysqladmin was not found in the configured MySQL tools path.")
            return
        }

        let handle = activityEngine?.begin("Stopping MySQL server", connectionSessionID: connectionSessionID)
        do {
            serverControlOutput = []
            let result = try await processRunner.run(
                executable: mysqladmin,
                arguments: [
                    "--host=\(mysql.configuration.host)",
                    "--port=\(mysql.configuration.port)",
                    "--user=\(mysql.configuration.username)",
                    "shutdown"
                ],
                environment: mysql.configuration.password.map { ["MYSQL_PWD": $0] } ?? [:],
                onStderr: { [weak self] line in
                    Task { @MainActor in
                        self?.serverControlOutput.append(line)
                    }
                }
            )

            if result.exitCode == 0 {
                serverControlState = .stopped
                handle?.succeed()
                panelState?.appendMessage("Stopped local MySQL server")
            } else {
                let message = result.stderrLines.last ?? "mysqladmin shutdown failed with exit code \(result.exitCode)"
                serverControlState = .unavailable(message)
                handle?.fail(message)
                panelState?.appendMessage("Failed to stop MySQL server: \(message)", severity: .error)
            }
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to stop MySQL server: \(error.localizedDescription)", severity: .error)
        }
    }

    func startLocalMySQLServer(customToolPath: String?) async {
        guard isLocalMySQLHost else {
            serverControlState = .unavailable("Server control is only available for local MySQL instances.")
            return
        }

        let handle = activityEngine?.begin("Starting MySQL server", connectionSessionID: connectionSessionID)
        serverControlOutput = []

        do {
            if let script = MySQLToolLocator.mysqlServerScriptURL(customPath: customToolPath) {
                let result = try await processRunner.run(
                    executable: script,
                    arguments: ["start"],
                    onStderr: { [weak self] line in
                        Task { @MainActor in
                            self?.serverControlOutput.append(line)
                        }
                    }
                )
                try await finalizeStart(result: result)
                handle?.succeed()
                return
            }

            if let mysqld = MySQLToolLocator.mysqldURL(customPath: customToolPath) {
                var arguments: [String] = []
                if let config = selectedConfigFile?.path, !config.isEmpty {
                    arguments.append("--defaults-file=\(config)")
                }
                arguments.append("--daemonize")
                let result = try await processRunner.run(
                    executable: mysqld,
                    arguments: arguments,
                    onStderr: { [weak self] line in
                        Task { @MainActor in
                            self?.serverControlOutput.append(line)
                        }
                    }
                )
                try await finalizeStart(result: result)
                handle?.succeed()
                return
            }

            serverControlState = .unavailable("No supported local MySQL start tool was found. Echo currently supports mysql.server or mysqld --daemonize.")
            handle?.fail("No supported local MySQL start tool was found")
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to start MySQL server: \(error.localizedDescription)", severity: .error)
        }
    }

    private func finalizeStart(result: ProcessResult) async throws {
        if result.exitCode == 0 {
            try await pollForRunningState()
            serverControlState = .running
            panelState?.appendMessage("Started local MySQL server")
        } else {
            let message = result.stderrLines.last ?? "MySQL start command failed with exit code \(result.exitCode)"
            serverControlState = .unavailable(message)
            throw ServerControlError.commandFailed(message)
        }
    }

    private func pollForRunningState() async throws {
        guard let mysql = session as? MySQLSession else { return }
        for _ in 0..<10 {
            do {
                try await withTemporaryClient(for: mysql) { client in
                    _ = try await client.admin.globalStatus(named: "Uptime")
                }
                return
            } catch {
                try await Task.sleep(for: .seconds(1))
            }
        }
        throw ServerControlError.commandFailed("The MySQL server did not become reachable after the start request.")
    }

    private func withTemporaryClient(
        for mysql: MySQLSession,
        _ operation: (MySQLClient) async throws -> Void
    ) async throws {
        let client = MySQLClient(configuration: mysql.configuration, logger: mysql.logger)
        defer {
            Task {
                await client.close()
            }
        }
        try await operation(client)
    }

    enum ServerControlError: LocalizedError {
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .commandFailed(let message):
                message
            }
        }
    }
}
