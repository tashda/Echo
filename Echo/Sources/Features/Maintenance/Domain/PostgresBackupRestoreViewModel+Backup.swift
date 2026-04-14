import Foundation

extension PostgresBackupRestoreViewModel {
    func executeBackup(customToolPath: String?) async {
        guard canBackup, let outputURL else { return }
        guard let pgDump = PostgresToolLocator.pgDumpURL(customPath: customToolPath) else {
            backupPhase = .failed(message: "pg_dump not found. Install PostgreSQL or configure a custom tool path in Settings.")
            return
        }

        backupPhase = .running
        backupStderrOutput = []
        let handle = activityEngine?.begin("Backup \(databaseName)", connectionSessionID: connectionSessionID)

        var args: [String] = []
        args.append(contentsOf: ["--dbname", buildConnectionURI(database: databaseName)])
        args.append(contentsOf: ["--format", outputFormat.pgDumpFlag])
        args.append(contentsOf: ["--file", outputURL.path])

        if (outputFormat == .custom || outputFormat == .directory) && compression > 0 {
            args.append(contentsOf: ["--compress", String(compression)])
        }
        if outputFormat == .directory && parallelJobs > 1 {
            args.append(contentsOf: ["--jobs", String(parallelJobs)])
        }
        if schemaOnly { args.append("--schema-only") }
        if dataOnly { args.append("--data-only") }
        if noOwner { args.append("--no-owner") }
        if noPrivileges { args.append("--no-privileges") }
        if noTablespaces { args.append("--no-tablespaces") }
        if clean { args.append("--clean") }
        if ifExists { args.append("--if-exists") }
        if createDatabase { args.append("--create") }
        if !encoding.isEmpty { args.append(contentsOf: ["--encoding", encoding]) }
        if !roleName.isEmpty { args.append(contentsOf: ["--role", roleName]) }
        if !includeBlobs && !dataOnly { args.append("--no-blobs") }
        if useInserts {
            if columnInserts {
                args.append("--column-inserts")
            } else {
                args.append("--inserts")
            }
            if rowsPerInsert > 0 {
                args.append(contentsOf: ["--rows-per-insert", String(rowsPerInsert)])
            }
            if onConflictDoNothing { args.append("--on-conflict-do-nothing") }
        }
        if disableTriggers { args.append("--disable-triggers") }
        if disableDollarQuoting { args.append("--disable-dollar-quoting") }
        if forceDoubleQuotes { args.append("--quote-all-identifiers") }
        if useSetSessionAuth { args.append("--use-set-session-authorization") }
        if !lockWaitTimeout.isEmpty { args.append(contentsOf: ["--lock-wait-timeout", lockWaitTimeout]) }
        if !extraFloatDigits.isEmpty { args.append(contentsOf: ["--extra-float-digits", extraFloatDigits]) }

        // Pattern-based filters
        for pattern in splitPatterns(includeTables) {
            args.append(contentsOf: ["--table", pattern])
        }
        for pattern in splitPatterns(excludeTables) {
            args.append(contentsOf: ["--exclude-table", pattern])
        }
        for pattern in splitPatterns(includeSchemas) {
            args.append(contentsOf: ["--schema", pattern])
        }
        for pattern in splitPatterns(excludeSchemas) {
            args.append(contentsOf: ["--exclude-schema", pattern])
        }
        for pattern in splitPatterns(excludeTableData) {
            args.append(contentsOf: ["--exclude-table-data", pattern])
        }

        args.append("--no-password")
        if verbose { args.append("--verbose") }

        // Extra arguments escape hatch
        let extraArgs = extraArguments.trimmingCharacters(in: .whitespaces)
        if !extraArgs.isEmpty {
            args.append(contentsOf: extraArgs.split(separator: " ").map(String.init))
        }

        let env = buildEnvironment()

        log("Starting backup of \(databaseName)\u{2026}", severity: .info, category: "Backup")
        nonisolated(unsafe) let panel = panelState

        do {
            let result = try await processRunner.run(
                executable: pgDump,
                arguments: args,
                environment: env
            ) { @Sendable line in
                Task { @MainActor in
                    panel?.appendMessage(line, severity: .info, category: "Backup")
                }
            }

            backupStderrOutput = result.stderrLines
            if result.exitCode == 0 {
                backupPhase = .completed(messages: [])
                log("Backup completed for \(databaseName) to \(outputURL.lastPathComponent).", severity: .success, category: "Backup")
                notificationEngine?.post(.backupCompleted(database: databaseName, destination: outputURL.lastPathComponent))
                handle?.succeed()
            } else {
                let errorMsg = result.stderrLines.last ?? "pg_dump exited with code \(result.exitCode)"
                backupPhase = .failed(message: errorMsg)
                log("Backup failed: \(errorMsg)", severity: .error, category: "Backup")
                notificationEngine?.post(.backupFailed(database: databaseName, reason: errorMsg))
                handle?.fail(errorMsg)
            }
        } catch {
            backupPhase = .failed(message: error.localizedDescription)
            log("Backup failed: \(error.localizedDescription)", severity: .error, category: "Backup")
            notificationEngine?.post(.backupFailed(database: databaseName, reason: error.localizedDescription))
            handle?.fail(error.localizedDescription)
        }
    }

    func cancelBackup() {
        if isBackupRunning {
            backupPhase = .failed(message: "Backup cancelled")
        }
    }
}
