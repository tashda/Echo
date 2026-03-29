import Foundation

extension ServerPropertiesViewModel {
    var isLocalPostgresHost: Bool {
        guard session is PostgresSession else { return false }
        let host = connectionHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host.isEmpty || host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    func refreshPostgresControlState() async {
        guard isLocalPostgresHost else {
            serverControlState = .unavailable("Server control is only available for local PostgreSQL instances.")
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Try to query the server to check if it's running
        do {
            let result = try await session.simpleQuery("SELECT 1")
            if !result.rows.isEmpty {
                serverControlState = .running
            } else {
                serverControlState = .stopped
            }
        } catch {
            serverControlState = .stopped
        }
    }

    func stopLocalPostgresServer(customToolPath: String?, dataDir: String?) async {
        guard isLocalPostgresHost else {
            serverControlState = .unavailable("Server control is only available for local PostgreSQL instances.")
            return
        }

        guard let plan = PostgresServerControlPlan.stop(dataDir: dataDir, customToolPath: customToolPath) else {
            serverControlState = .unavailable("pg_ctl was not found. Install PostgreSQL or configure the tool path in Preferences.")
            return
        }

        let handle = activityEngine?.begin("Stopping PostgreSQL server", connectionSessionID: connectionSessionID)
        serverControlOutput = []

        do {
            let result = try await processRunner.run(
                executable: plan.executable,
                arguments: plan.arguments,
                environment: plan.environment,
                onStderr: { [weak self] line in
                    Task { @MainActor in self?.serverControlOutput.append(line) }
                }
            )

            if result.exitCode == 0 {
                serverControlState = .stopped
                handle?.succeed()
                panelState?.appendMessage("Stopped local PostgreSQL server")
            } else {
                let message = result.stderrLines.last ?? "pg_ctl stop failed with exit code \(result.exitCode)"
                serverControlState = .unavailable(message)
                handle?.fail(message)
            }
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }

    func startLocalPostgresServer(customToolPath: String?, dataDir: String?, logFile: String?) async {
        guard isLocalPostgresHost else {
            serverControlState = .unavailable("Server control is only available for local PostgreSQL instances.")
            return
        }

        guard let plan = PostgresServerControlPlan.start(dataDir: dataDir, customToolPath: customToolPath, logFile: logFile) else {
            serverControlState = .unavailable("pg_ctl was not found. Install PostgreSQL or configure the tool path in Preferences.")
            return
        }

        let handle = activityEngine?.begin("Starting PostgreSQL server", connectionSessionID: connectionSessionID)
        serverControlOutput = []

        do {
            let result = try await processRunner.run(
                executable: plan.executable,
                arguments: plan.arguments,
                environment: plan.environment,
                onStderr: { [weak self] line in
                    Task { @MainActor in self?.serverControlOutput.append(line) }
                }
            )

            if result.exitCode == 0 {
                // Poll for the server to become available
                for _ in 0..<10 {
                    do {
                        let check = try await session.simpleQuery("SELECT 1")
                        if !check.rows.isEmpty {
                            serverControlState = .running
                            handle?.succeed()
                            panelState?.appendMessage("Started local PostgreSQL server")
                            return
                        }
                    } catch {
                        try? await Task.sleep(for: .seconds(1))
                    }
                }
                serverControlState = .running
                handle?.succeed()
            } else {
                let message = result.stderrLines.last ?? "pg_ctl start failed with exit code \(result.exitCode)"
                serverControlState = .unavailable(message)
                handle?.fail(message)
            }
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }

    func restartLocalPostgresServer(customToolPath: String?, dataDir: String?, logFile: String?) async {
        guard isLocalPostgresHost else {
            serverControlState = .unavailable("Server control is only available for local PostgreSQL instances.")
            return
        }

        guard let plan = PostgresServerControlPlan.restart(dataDir: dataDir, customToolPath: customToolPath, logFile: logFile) else {
            serverControlState = .unavailable("pg_ctl was not found. Install PostgreSQL or configure the tool path in Preferences.")
            return
        }

        let handle = activityEngine?.begin("Restarting PostgreSQL server", connectionSessionID: connectionSessionID)
        serverControlOutput = []

        do {
            let result = try await processRunner.run(
                executable: plan.executable,
                arguments: plan.arguments,
                environment: plan.environment,
                onStderr: { [weak self] line in
                    Task { @MainActor in self?.serverControlOutput.append(line) }
                }
            )

            if result.exitCode == 0 {
                serverControlState = .running
                handle?.succeed()
                panelState?.appendMessage("Restarted local PostgreSQL server")
            } else {
                let message = result.stderrLines.last ?? "pg_ctl restart failed with exit code \(result.exitCode)"
                serverControlState = .unavailable(message)
                handle?.fail(message)
            }
        } catch {
            serverControlState = .unavailable(error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - PostgreSQL Overview

    func loadPostgresOverview() async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading PostgreSQL server overview", connectionSessionID: connectionSessionID)
        do {
            let result = try await session.simpleQuery("""
                SELECT version() AS version,
                       current_setting('server_version') AS server_version,
                       current_setting('port') AS port,
                       current_setting('max_connections') AS max_connections,
                       current_setting('shared_buffers') AS shared_buffers,
                       current_setting('work_mem') AS work_mem,
                       current_setting('server_encoding') AS encoding,
                       current_setting('lc_collate') AS collation,
                       pg_postmaster_start_time()::text AS start_time,
                       (SELECT count(*) FROM pg_stat_activity)::text AS active_connections
            """)

            guard let row = result.rows.first else {
                handle?.succeed()
                return
            }

            overviewItems = [
                PropertyItem(id: "version", name: "Version", value: row[safe: 1] ?? "\u{2014}"),
                PropertyItem(id: "full-version", name: "Full Version", value: row[safe: 0] ?? "\u{2014}"),
                PropertyItem(id: "port", name: "Port", value: row[safe: 2] ?? "\u{2014}"),
                PropertyItem(id: "max-connections", name: "Max Connections", value: row[safe: 3] ?? "\u{2014}"),
                PropertyItem(id: "shared-buffers", name: "Shared Buffers", value: row[safe: 4] ?? "\u{2014}"),
                PropertyItem(id: "work-mem", name: "Work Memory", value: row[safe: 5] ?? "\u{2014}"),
                PropertyItem(id: "encoding", name: "Encoding", value: row[safe: 6] ?? "\u{2014}"),
                PropertyItem(id: "collation", name: "Collation", value: row[safe: 7] ?? "\u{2014}"),
                PropertyItem(id: "start-time", name: "Start Time", value: row[safe: 8] ?? "\u{2014}"),
                PropertyItem(id: "active-connections", name: "Active Connections", value: row[safe: 9] ?? "\u{2014}"),
            ]
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
            panelState?.appendMessage("Failed to load PostgreSQL overview: \(error.localizedDescription)", severity: .error)
        }
    }

    // MARK: - PostgreSQL Variables

    func loadPostgresVariables() async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading PostgreSQL settings", connectionSessionID: connectionSessionID)
        do {
            let result = try await session.simpleQuery("SELECT name, setting, category FROM pg_settings ORDER BY name")
            variables = result.rows.map { row in
                PropertyItem(
                    id: row[safe: 0] ?? UUID().uuidString,
                    name: row[safe: 0] ?? "\u{2014}",
                    value: row[safe: 1] ?? "\u{2014}",
                    category: row[safe: 2]
                )
            }
            if selectedVariable == nil {
                selectedVariableID = variables.first.map { [$0.id] } ?? []
            }
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - PostgreSQL Status

    func loadPostgresStatus() async {
        isLoading = true
        defer { isLoading = false }
        let handle = activityEngine?.begin("Loading PostgreSQL statistics", connectionSessionID: connectionSessionID)
        do {
            let result = try await session.simpleQuery("""
                SELECT
                    'Backends' AS name, numbackends::text AS value FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Transactions Committed', xact_commit::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Transactions Rolled Back', xact_rollback::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Blocks Read', blks_read::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Blocks Hit', blks_hit::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Rows Returned', tup_returned::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Rows Fetched', tup_fetched::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Rows Inserted', tup_inserted::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Rows Updated', tup_updated::text FROM pg_stat_database WHERE datname = current_database()
                UNION ALL
                SELECT 'Rows Deleted', tup_deleted::text FROM pg_stat_database WHERE datname = current_database()
            """)
            statusVariables = result.rows.map { row in
                PropertyItem(
                    id: row[safe: 0] ?? UUID().uuidString,
                    name: row[safe: 0] ?? "\u{2014}",
                    value: row[safe: 1] ?? "\u{2014}"
                )
            }
            handle?.succeed()
        } catch {
            handle?.fail(error.localizedDescription)
        }
    }

    // MARK: - Load section dispatcher for Postgres

    func loadPostgresSection() async {
        switch selectedSection {
        case .overview:
            await loadPostgresOverview()
        case .control:
            await refreshPostgresControlState()
        case .variables:
            await loadPostgresVariables()
        case .status:
            await loadPostgresStatus()
        case .logs, .configuration:
            break
        }
    }
}
