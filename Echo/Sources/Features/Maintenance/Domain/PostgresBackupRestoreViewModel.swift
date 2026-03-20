import Foundation
import AppKit

@MainActor
@Observable
final class PostgresBackupRestoreViewModel {
    let connection: SavedConnection
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored private let processRunner = PostgresProcessRunner()
    @ObservationIgnored private let connectionPassword: String?
    @ObservationIgnored private let resolvedUsername: String?
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?
    @ObservationIgnored var panelState: BottomPanelState?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    enum ActiveForm {
        case backup
        case restore
    }

    var activeForm: ActiveForm?

    // MARK: - Backup State

    var databaseName: String
    var outputFormat: PgDumpFormat = .custom
    var outputURL: URL?
    var outputPath: String = "" {
        didSet {
            let trimmed = outputPath.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let url = URL(fileURLWithPath: trimmed)
                if outputURL?.path != url.path {
                    outputURL = url
                }
            }
        }
    }
    var schemaOnly = false
    var dataOnly = false
    var noOwner = false
    var noPrivileges = false
    var noTablespaces = false
    var clean = false
    var ifExists = false
    var createDatabase = false
    var compression: Int = 6
    var parallelJobs: Int = 1
    var encoding: String = ""
    var roleName: String = ""
    var includeBlobs = true
    var includeTables: String = ""
    var excludeTables: String = ""
    var includeSchemas: String = ""
    var excludeSchemas: String = ""
    var excludeTableData: String = ""
    var useInserts = false
    var columnInserts = false
    var rowsPerInsert: Int = 0
    var onConflictDoNothing = false
    var verbose = true
    var disableTriggers = false
    var disableDollarQuoting = false
    var forceDoubleQuotes = false
    var useSetSessionAuth = false
    var lockWaitTimeout: String = ""
    var extraFloatDigits: String = ""
    var extraArguments: String = ""
    var backupPhase: PostgresBackupPhase = .idle
    var backupStderrOutput: [String] = []

    // MARK: - Restore State

    var restoreDatabaseName: String = ""
    var inputURL: URL?
    var inputPath: String = "" {
        didSet {
            let trimmed = inputPath.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                let url = URL(fileURLWithPath: trimmed)
                if inputURL?.path != url.path {
                    inputURL = url
                    detectFormat()
                }
            }
        }
    }
    var detectedFormat: PgDumpFormat?
    var restoreSchemaOnly = false
    var restoreDataOnly = false
    var restoreNoOwner = false
    var restoreNoPrivileges = false
    var restoreNoTablespaces = false
    var restoreClean = false
    var restoreIfExists = false
    var restoreCreateDatabase = false
    var restoreUseSetSessionAuth = false
    var restoreDisableTriggers = false
    var restoreParallelJobs: Int = 1
    var restoreVerbose = true
    var restoreExtraArguments: String = ""
    var dumpContents: [PgRestoreListItem] = []
    var restorePhase: PostgresRestorePhase = .idle
    var restoreStderrOutput: [String] = []

    // MARK: - Computed

    var isBackupRunning: Bool { backupPhase == .running }
    var isRestoreRunning: Bool { restorePhase == .running }

    var canBackup: Bool {
        !databaseName.isEmpty && outputURL != nil && !isBackupRunning
    }

    var canRestore: Bool {
        !restoreDatabaseName.isEmpty && inputURL != nil && !isRestoreRunning
    }

    var canListContents: Bool {
        inputURL != nil && !isRestoreRunning
    }

    // MARK: - Init

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, password: String? = nil, resolvedUsername: String? = nil) {
        self.connection = connection
        self.session = session
        self.databaseName = databaseName
        self.restoreDatabaseName = databaseName
        self.connectionPassword = password
        self.resolvedUsername = resolvedUsername
    }

    func resetBackupState() {
        outputFormat = .custom
        outputURL = nil
        outputPath = ""
        schemaOnly = false
        dataOnly = false
        noOwner = false
        noPrivileges = false
        noTablespaces = false
        clean = false
        ifExists = false
        createDatabase = false
        compression = 6
        parallelJobs = 1
        encoding = ""
        roleName = ""
        includeBlobs = true
        includeTables = ""
        excludeTables = ""
        includeSchemas = ""
        excludeSchemas = ""
        excludeTableData = ""
        useInserts = false
        columnInserts = false
        rowsPerInsert = 0
        onConflictDoNothing = false
        verbose = true
        disableTriggers = false
        disableDollarQuoting = false
        forceDoubleQuotes = false
        useSetSessionAuth = false
        lockWaitTimeout = ""
        extraFloatDigits = ""
        extraArguments = ""
        backupPhase = .idle
        backupStderrOutput = []
    }

    func resetRestoreState() {
        inputURL = nil
        inputPath = ""
        detectedFormat = nil
        restoreSchemaOnly = false
        restoreDataOnly = false
        restoreNoOwner = false
        restoreNoPrivileges = false
        restoreNoTablespaces = false
        restoreClean = false
        restoreIfExists = false
        restoreCreateDatabase = false
        restoreUseSetSessionAuth = false
        restoreDisableTriggers = false
        restoreParallelJobs = 1
        restoreVerbose = true
        restoreExtraArguments = ""
        dumpContents = []
        restorePhase = .idle
        restoreStderrOutput = []
    }

    private func log(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Backup") {
        panelState?.appendMessage(text, severity: severity, category: category)
    }

    // MARK: - File Pickers

    func selectOutputFile() {
        if outputFormat == .directory {
            let panel = NSOpenPanel()
            panel.title = "Choose Backup Directory"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            panel.allowsMultipleSelection = false
            if panel.runModal() == .OK, let url = panel.url {
                outputURL = url
                outputPath = url.path
            }
        } else {
            let panel = NSSavePanel()
            panel.title = "Save Backup"
            let ext = outputFormat == .plain ? "sql" : outputFormat == .tar ? "tar" : "dump"
            panel.nameFieldStringValue = "\(databaseName).\(ext)"
            panel.canCreateDirectories = true
            if panel.runModal() == .OK, let url = panel.url {
                outputURL = url
                outputPath = url.path
            }
        }
    }

    func selectInputFile() {
        let panel = NSOpenPanel()
        panel.title = "Select Backup File"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = true

        if panel.runModal() == .OK, let url = panel.url {
            inputURL = url
            inputPath = url.path
            detectFormat()
        }
    }

    // MARK: - Backup

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

    // MARK: - Restore

    func executeRestore(customToolPath: String?) async {
        guard canRestore, let inputURL else { return }

        if isPlainSQL(url: inputURL) {
            await restorePlainSQL(from: inputURL)
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

    // MARK: - Private

    private func splitPatterns(_ input: String) -> [String] {
        input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func buildConnectionURI(database: String) -> String {
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

    private func buildEnvironment() -> [String: String] {
        var env: [String: String] = [:]
        if let password = connectionPassword, !password.isEmpty {
            env["PGPASSWORD"] = password
        }
        env["PGSSLMODE"] = connection.useTLS ? "require" : "disable"
        if let sharedSupport = Bundle.main.sharedSupportURL {
            let toolsDir = sharedSupport.appendingPathComponent("PostgresTools").path
            env["DYLD_LIBRARY_PATH"] = toolsDir
            env["DYLD_FALLBACK_LIBRARY_PATH"] = toolsDir
        }
        return env
    }

    private func detectFormat() {
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

    private func isPlainSQL(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if ext == "sql" { return true }
        guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
        defer { handle.closeFile() }
        guard let data = try? handle.read(upToCount: 32) else { return false }
        guard let header = String(data: data, encoding: .utf8) else { return false }
        let trimmed = header.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("--") || trimmed.hasPrefix("CREATE") || trimmed.hasPrefix("SET")
    }

    private func restorePlainSQL(from url: URL) async {
        restorePhase = .running
        restoreStderrOutput = []
        let handle = activityEngine?.begin("Restore \(restoreDatabaseName)", connectionSessionID: connectionSessionID)
        do {
            let sql = try String(contentsOf: url, encoding: .utf8)
            let dbSession = try await session.sessionForDatabase(restoreDatabaseName)
            _ = try await dbSession.simpleQuery(sql)
            restorePhase = .completed(messages: ["Plain SQL restore completed."])
            handle?.succeed()
        } catch {
            restorePhase = .failed(message: error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }
}
