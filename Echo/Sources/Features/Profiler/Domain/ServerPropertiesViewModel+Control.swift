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
                _ = try await client.serverConfig.globalStatus(named: "Uptime")
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
        guard let plan = MySQLServerControlPlan.stop(
            host: mysql.configuration.host,
            port: mysql.configuration.port,
            username: mysql.configuration.username,
            password: mysql.configuration.password,
            customToolPath: customToolPath
        ) else {
            serverControlState = .unavailable("mysqladmin was not found in the configured MySQL tools path.")
            return
        }

        let handle = activityEngine?.begin("Stopping MySQL server", connectionSessionID: connectionSessionID)
        do {
            serverControlOutput = []
            let result = try await runServerControlPlan(plan)

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
            if let plan = MySQLServerControlPlan.start(
                customToolPath: customToolPath,
                defaultsFilePath: selectedConfigFile?.path
            ) {
                let result = try await runServerControlPlan(plan)
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

    func restartLocalMySQLServer(customToolPath: String?) async {
        guard let mysql = session as? MySQLSession else { return }
        guard isLocalMySQLHost else {
            serverControlState = .unavailable("Server control is only available for local MySQL instances.")
            return
        }
        guard let plan = MySQLServerControlPlan.restart(
            host: mysql.configuration.host,
            port: mysql.configuration.port,
            username: mysql.configuration.username,
            password: mysql.configuration.password,
            customToolPath: customToolPath,
            defaultsFilePath: selectedConfigFile?.path
        ) else {
            serverControlState = .unavailable("No supported local MySQL restart workflow was found. Echo currently supports mysql.server restart or mysqladmin shutdown plus mysqld --daemonize.")
            return
        }

        let handle = activityEngine?.begin("Restarting MySQL server", connectionSessionID: connectionSessionID)
        serverControlOutput = []

        do {
            switch plan {
            case .single(let processPlan):
                let result = try await runServerControlPlan(processPlan)
                try await finalizeStart(result: result)
            case .stopThenStart(let stopPlan, let startPlan):
                let stopResult = try await runServerControlPlan(stopPlan)
                guard stopResult.exitCode == 0 else {
                    let message = stopResult.stderrLines.last ?? "MySQL stop command failed with exit code \(stopResult.exitCode)"
                    serverControlState = .unavailable(message)
                    throw ServerControlError.commandFailed(message)
                }
                let startResult = try await runServerControlPlan(startPlan)
                try await finalizeStart(result: startResult)
            }

            handle?.succeed()
            panelState?.appendMessage("Restarted local MySQL server")
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to restart MySQL server: \(error.localizedDescription)", severity: .error)
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
                    _ = try await client.serverConfig.globalStatus(named: "Uptime")
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

    private func runServerControlPlan(_ plan: MySQLServerControlProcessPlan) async throws -> ProcessResult {
        try await processRunner.run(
            executable: plan.executable,
            arguments: plan.arguments,
            environment: plan.environment,
            onStderr: { [weak self] line in
                Task { @MainActor in
                    self?.serverControlOutput.append(line)
                }
            }
        )
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
