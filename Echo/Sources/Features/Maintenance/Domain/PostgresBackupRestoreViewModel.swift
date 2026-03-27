import Foundation
import AppKit

@Observable
final class PostgresBackupRestoreViewModel {
    let connection: SavedConnection
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored let processRunner = PostgresProcessRunner()
    @ObservationIgnored let connectionPassword: String?
    @ObservationIgnored let resolvedUsername: String?
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

    func log(_ text: String, severity: QueryExecutionMessage.Severity = .info, category: String = "Backup") {
        panelState?.appendMessage(text, severity: severity, category: category)
    }

    // MARK: - File Pickers

    @MainActor
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

    @MainActor
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
}
