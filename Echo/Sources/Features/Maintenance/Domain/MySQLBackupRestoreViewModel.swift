import AppKit
import Foundation

@Observable
final class MySQLBackupRestoreViewModel {
    enum Phase: Equatable {
        case idle
        case running
        case completed(message: String)
        case failed(message: String)
    }

    let connection: SavedConnection
    @ObservationIgnored let session: DatabaseSession
    @ObservationIgnored let processRunner = MySQLProcessRunner()
    @ObservationIgnored let connectionPassword: String?
    @ObservationIgnored let resolvedUsername: String?
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?
    @ObservationIgnored var notificationEngine: NotificationEngine?

    var databaseName: String
    var outputPath: String = ""
    var inputPath: String = ""
    var includeRoutines = true
    var includeEvents = true
    var includeTriggers = true
    var includeData = true
    var singleTransaction = true
    var forceRestore = false
    var backupPhase: Phase = .idle
    var restorePhase: Phase = .idle
    var backupOutput: [String] = []
    var restoreOutput: [String] = []

    var isBackupRunning: Bool { backupPhase == .running }
    var isRestoreRunning: Bool { restorePhase == .running }
    var canBackup: Bool { !databaseName.isEmpty && !outputPath.trimmingCharacters(in: .whitespaces).isEmpty && !isBackupRunning }
    var canRestore: Bool { !databaseName.isEmpty && !inputPath.trimmingCharacters(in: .whitespaces).isEmpty && !isRestoreRunning }

    init(connection: SavedConnection, session: DatabaseSession, databaseName: String, password: String? = nil, resolvedUsername: String? = nil) {
        self.connection = connection
        self.session = session
        self.databaseName = databaseName
        self.connectionPassword = password
        self.resolvedUsername = resolvedUsername
    }

    @MainActor
    func selectBackupFile() {
        let panel = NSSavePanel()
        panel.title = "Save MySQL Backup"
        panel.nameFieldStringValue = "\(databaseName).sql"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url {
            outputPath = url.path
        }
    }

    @MainActor
    func selectRestoreFile() {
        let panel = NSOpenPanel()
        panel.title = "Select MySQL Backup File"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            inputPath = url.path
        }
    }
}
