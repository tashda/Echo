import Foundation

extension PostgresBackupRestoreViewModel {
    func executeRestore(customToolPath: String?) async {
        guard canRestore, let inputURL else { return }

        if isPlainSQL(url: inputURL) {
            await restorePlainSQL(from: inputURL, customToolPath: customToolPath)
            return
        }

        guard let pgRestore = PostgresToolLocator.pgRestoreURL(customPath: customToolPath) else {
            restorePhase = .failed(message: "pg_restore not found. Install PostgreSQL or configure a custom tool path in Settings.")
            return
        }

        restorePhase = .running
        restoreStderrOutput = []
        let handle = activityEngine?.begin("Restore \(restoreDatabaseName)", connectionSessionID: connectionSessionID)

        var args: [String] = []
        args.append(contentsOf: ["--dbname", buildConnectionURI(database: restoreDatabaseName)])

        if restoreSchemaOnly { args.append("--schema-only") }
        if restoreDataOnly { args.append("--data-only") }
        if restoreNoOwner { args.append("--no-owner") }
        if restoreNoPrivileges { args.append("--no-privileges") }
        if restoreNoTablespaces { args.append("--no-tablespaces") }
        if restoreClean { args.append("--clean") }
        if restoreIfExists { args.append("--if-exists") }
        if restoreCreateDatabase { args.append("--create") }
        if restoreUseSetSessionAuth { args.append("--use-set-session-authorization") }
        if restoreDisableTriggers { args.append("--disable-triggers") }
        args.append("--no-password")
        if restoreParallelJobs > 1 {
            args.append(contentsOf: ["--jobs", String(restoreParallelJobs)])
        }
        if restoreVerbose { args.append("--verbose") }

        // Extra arguments escape hatch
        let extraArgs = restoreExtraArguments.trimmingCharacters(in: .whitespaces)
        if !extraArgs.isEmpty {
            args.append(contentsOf: extraArgs.split(separator: " ").map(String.init))
        }

        args.append(inputURL.path)

        let env = buildEnvironment()
        log("Starting restore to \(restoreDatabaseName)\u{2026}", severity: .info, category: "Restore")
        nonisolated(unsafe) let panel = panelState

        do {
            let result = try await processRunner.run(
                executable: pgRestore,
                arguments: args,
                environment: env
            ) { @Sendable line in
                Task { @MainActor in
                    let sev: QueryExecutionMessage.Severity = line.contains("error:") ? .error : line.contains("warning:") ? .warning : .info
                    panel?.appendMessage(line, severity: sev, category: "Restore")
                }
            }

            restoreStderrOutput = result.stderrLines
            if result.exitCode == 0 {
                restorePhase = .completed(messages: [])
                log("Restore completed for \(restoreDatabaseName).", severity: .success, category: "Restore")
                notificationEngine?.post(.restoreCompleted(database: restoreDatabaseName))
                handle?.succeed()
            } else {
                let errorMsg = result.stderrLines.last ?? "pg_restore exited with code \(result.exitCode)"
                restorePhase = .failed(message: errorMsg)
                log("Restore failed: \(errorMsg)", severity: .error, category: "Restore")
                notificationEngine?.post(.restoreFailed(database: restoreDatabaseName, reason: errorMsg))
                handle?.fail(errorMsg)
            }
        } catch {
            restorePhase = .failed(message: error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }

    func cancelRestore() {
        if isRestoreRunning {
            restorePhase = .failed(message: "Restore cancelled")
        }
    }

    // MARK: - List Contents

    func listContents(customToolPath: String?) async {
        guard let inputURL else { return }
        guard let pgRestore = PostgresToolLocator.pgRestoreURL(customPath: customToolPath) else { return }

        do {
            // pg_restore --list outputs to stdout — run via Process directly
            let listProcess = Process()
            listProcess.executableURL = pgRestore
            listProcess.arguments = ["--list", inputURL.path]
            let pipe = Pipe()
            listProcess.standardOutput = pipe
            listProcess.standardError = Pipe()
            try listProcess.run()
            listProcess.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let lines = output.split(separator: "\n").filter { !$0.hasPrefix(";") }

            dumpContents = lines.enumerated().compactMap { index, line in
                let str = String(line).trimmingCharacters(in: .whitespaces)
                guard !str.isEmpty else { return nil }
                let parts = str.split(separator: " ", maxSplits: 6).map(String.init)
                guard parts.count >= 4 else {
                    return PgRestoreListItem(id: index, line: str, type: "UNKNOWN", schema: nil, name: str)
                }
                let type = parts.count > 3 ? parts[3] : "UNKNOWN"
                let schema = parts.count > 4 ? parts[4] : nil
                let name = parts.count > 5 ? parts[5] : (parts.last ?? "")
                return PgRestoreListItem(id: index, line: str, type: type, schema: schema, name: name)
            }
        } catch {
            dumpContents = []
        }
    }

    private func restorePlainSQL(from url: URL, customToolPath: String?) async {
        restorePhase = .running
        restoreStderrOutput = []
        let handle = activityEngine?.begin("Restore \(restoreDatabaseName)", connectionSessionID: connectionSessionID)
        guard let psql = PostgresToolLocator.psqlURL(customPath: customToolPath) else {
            restorePhase = .failed(message: "psql not found. Install PostgreSQL or configure a custom tool path in Settings.")
            handle?.fail("psql not found")
            return
        }

        let env = buildEnvironment()
        nonisolated(unsafe) let panel = panelState

        do {
            let result = try await processRunner.run(
                executable: psql,
                arguments: [
                    "--dbname", buildConnectionURI(database: restoreDatabaseName),
                    "--file", url.path,
                    "--no-password"
                ],
                environment: env
            ) { @Sendable line in
                Task { @MainActor in
                    let severity: QueryExecutionMessage.Severity = line.contains("ERROR:") ? .error : line.contains("WARNING:") ? .warning : .info
                    panel?.appendMessage(line, severity: severity, category: "Restore")
                }
            }

            restoreStderrOutput = result.stderrLines
            if result.exitCode == 0 {
                restorePhase = .completed(messages: ["Plain SQL restore completed."])
                handle?.succeed()
            } else {
                let errorMsg = result.stderrLines.last ?? "psql exited with code \(result.exitCode)"
                restorePhase = .failed(message: errorMsg)
                handle?.fail(errorMsg)
            }
        } catch {
            restorePhase = .failed(message: error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }
}
