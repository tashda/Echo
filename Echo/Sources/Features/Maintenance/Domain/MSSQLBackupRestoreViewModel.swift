import Foundation
import SQLServerKit

enum BackupPhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

enum RestorePhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

enum MSSQLBackupPage: String, CaseIterable, Hashable {
    case general
    case media
    case options
    case encryption

    var title: String {
        switch self {
        case .general: return "General"
        case .media: return "Media"
        case .options: return "Options"
        case .encryption: return "Encryption"
        }
    }

    var icon: String {
        switch self {
        case .general: return "doc.badge.plus"
        case .media: return "opticaldisc"
        case .options: return "gearshape"
        case .encryption: return "lock.shield"
        }
    }
}

enum MSSQLRestorePage: String, CaseIterable, Hashable {
    case general
    case files
    case options
    case recovery
    case verify

    var title: String {
        switch self {
        case .general: return "General"
        case .files: return "Files"
        case .options: return "Options"
        case .recovery: return "Recovery"
        case .verify: return "Verify"
        }
    }

    var icon: String {
        switch self {
        case .general: return "arrow.counterclockwise"
        case .files: return "doc.on.doc"
        case .options: return "gearshape"
        case .recovery: return "clock.arrow.circlepath"
        case .verify: return "checkmark.shield"
        }
    }
}

enum MSSQLRestoreRecoveryMode: String, CaseIterable {
    case recovery = "RECOVERY"
    case noRecovery = "NORECOVERY"
    case standby = "STANDBY"

    var title: String {
        switch self {
        case .recovery: return "Recovery"
        case .noRecovery: return "No Recovery"
        case .standby: return "Standby"
        }
    }
}

@Observable
final class MSSQLBackupRestoreViewModel {
    @ObservationIgnored private let session: DatabaseSession
    @ObservationIgnored var activityEngine: ActivityEngine?
    @ObservationIgnored var connectionSessionID: UUID?
    @ObservationIgnored var notificationEngine: NotificationEngine?
    @ObservationIgnored var panelState: BottomPanelState?

    enum ActiveForm {
        case backup
        case restore
    }

    var activeForm: ActiveForm?

    // MARK: - Backup State

    var databaseName: String
    var backupType: SQLServerBackupType = .full
    var diskPath: String = ""
    var backupName: String = ""
    var backupDescription: String = ""
    var compression = false
    var copyOnly = false
    var checksum = false
    var continueOnError = false
    var initMedia = false
    var formatMedia = false
    var mediaName: String = ""
    var verifyAfterBackup = false
    var useExpireDate = false
    var expireDate = Date().addingTimeInterval(30 * 24 * 3600) // 30 days from now
    var encryptionEnabled = false
    var encryptionAlgorithm: SQLServerBackupEncryptionAlgorithm = .aes256
    var encryptionCertificate: String = ""
    var backupPhase: BackupPhase = .idle

    // MARK: - Restore State

    var restoreDatabaseName: String = ""
    var restoreDiskPath: String = ""
    var fileNumber: Int = 1
    var recoveryMode: MSSQLRestoreRecoveryMode = .recovery
    var standbyFile: String = ""
    var replace = false
    var closeConnections = false
    var keepReplication = false
    var restrictedUser = false
    var restoreChecksum = false
    var restoreContinueOnError = false
    var usePointInTimeRecovery = false
    var stopAtDate = Date()
    var backupSets: [SQLServerBackupSetInfo] = []
    var backupFiles: [SQLServerBackupFileInfo] = []
    var fileRelocations: [FileRelocationEntry] = []
    var isLoadingSets = false
    var loadError: String?
    var restorePhase: RestorePhase = .idle

    // MARK: - Verify State

    var verifyPhase: BackupPhase = .idle

    // MARK: - Computed

    var isBackupRunning: Bool { backupPhase == .running }
    var isRestoreRunning: Bool { restorePhase == .running }
    var isVerifying: Bool { verifyPhase == .running }

    var canBackup: Bool {
        !diskPath.trimmingCharacters(in: .whitespaces).isEmpty
        && !databaseName.isEmpty
        && !isBackupRunning
    }

    var canRestore: Bool {
        !restoreDiskPath.trimmingCharacters(in: .whitespaces).isEmpty
        && !restoreDatabaseName.isEmpty
        && !isRestoreRunning
    }

    var canListSets: Bool {
        !restoreDiskPath.trimmingCharacters(in: .whitespaces).isEmpty && !isLoadingSets
    }

    // MARK: - Init

    init(session: DatabaseSession, databaseName: String) {
        self.session = session
        self.databaseName = databaseName
        self.restoreDatabaseName = databaseName
        self.backupName = "\(databaseName) - Full Backup"
    }

    func resetBackupState() {
        backupType = .full
        diskPath = ""
        backupName = "\(databaseName) - Full Backup"
        backupDescription = ""
        compression = false
        copyOnly = false
        checksum = false
        continueOnError = false
        initMedia = false
        formatMedia = false
        mediaName = ""
        verifyAfterBackup = false
        useExpireDate = false
        expireDate = Date().addingTimeInterval(30 * 24 * 3600)
        encryptionEnabled = false
        encryptionAlgorithm = .aes256
        encryptionCertificate = ""
        backupPhase = .idle
    }

    func resetRestoreState() {
        restoreDiskPath = ""
        fileNumber = 1
        recoveryMode = .recovery
        standbyFile = ""
        replace = false
        closeConnections = false
        keepReplication = false
        restrictedUser = false
        restoreChecksum = false
        restoreContinueOnError = false
        usePointInTimeRecovery = false
        stopAtDate = Date()
        backupSets = []
        backupFiles = []
        fileRelocations = []
        loadError = nil
        restorePhase = .idle
        verifyPhase = .idle
    }

    // MARK: - Backup

    func executeBackup() async {
        guard canBackup else { return }
        backupPhase = .running
        let handle = activityEngine?.begin("Backup \(databaseName)", connectionSessionID: connectionSessionID)

        var encryption: SQLServerBackupEncryption?
        if encryptionEnabled && !encryptionCertificate.isEmpty {
            encryption = SQLServerBackupEncryption(
                algorithm: encryptionAlgorithm,
                serverCertificate: encryptionCertificate
            )
        }

        let options = SQLServerBackupOptions(
            database: databaseName,
            diskPath: diskPath.trimmingCharacters(in: .whitespaces),
            backupType: backupType,
            backupName: backupName.isEmpty ? nil : backupName,
            description: backupDescription.isEmpty ? nil : backupDescription,
            compression: compression,
            copyOnly: copyOnly,
            checksum: checksum,
            continueAfterError: continueOnError,
            initMedia: initMedia,
            formatMedia: formatMedia,
            mediaName: mediaName.isEmpty ? nil : mediaName,
            verifyAfterBackup: verifyAfterBackup,
            expireDate: useExpireDate ? expireDate : nil,
            encryption: encryption
        )
        do {
            guard let adapter = session as? SQLServerSessionAdapter else {
                backupPhase = .failed(message: "Not a SQL Server session")
                handle?.fail("Not a SQL Server session")
                return
            }
            let messages = try await adapter.client.backupRestore.backup(options: options)
            let infoMessages = messages.filter { $0.kind == .info }.map(\.message)

            if verifyAfterBackup {
                handle?.updateMessage("Verifying backup\u{2026}")
                let verifyMessages = try await adapter.client.backupRestore.verifyBackup(
                    diskPath: diskPath.trimmingCharacters(in: .whitespaces),
                    fileNumber: 1
                )
                let verifyInfo = verifyMessages.filter { $0.kind == .info }.map(\.message)
                backupPhase = .completed(messages: infoMessages + [""] + ["Verify:"] + verifyInfo)
            } else {
                backupPhase = .completed(messages: infoMessages)
            }

            panelState?.appendMessage("Backup completed for \(databaseName).", severity: .success, category: "Backup")
            notificationEngine?.post(.backupCompleted(database: databaseName, destination: diskPath))
            handle?.succeed()
        } catch {
            backupPhase = .failed(message: error.localizedDescription)
            panelState?.appendMessage("Backup failed: \(error.localizedDescription)", severity: .error, category: "Backup")
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

    func listBackupSets() async {
        let path = restoreDiskPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        isLoadingSets = true
        loadError = nil
        backupSets = []
        backupFiles = []
        fileRelocations = []

        do {
            guard let adapter = session as? SQLServerSessionAdapter else {
                loadError = "Not a SQL Server session"
                isLoadingSets = false
                return
            }
            let restoreClient = adapter.client.backupRestore
            let loadedSets = try await restoreClient.listBackupSets(diskPath: path)
            let loadedFiles = try await restoreClient.listBackupFiles(diskPath: path)
            backupSets = loadedSets
            backupFiles = loadedFiles
            fileRelocations = loadedFiles.map { file in
                FileRelocationEntry(
                    logicalName: file.logicalName,
                    originalPath: file.physicalName,
                    relocatedPath: file.physicalName
                )
            }
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingSets = false
    }

    func executeRestore() async {
        guard canRestore else { return }
        restorePhase = .running
        let handle = activityEngine?.begin("Restore \(restoreDatabaseName)", connectionSessionID: connectionSessionID)

        let relocations = fileRelocations
            .filter { $0.relocatedPath != $0.originalPath }
            .map { SQLServerRestoreOptions.FileRelocation(logicalName: $0.logicalName, physicalPath: $0.relocatedPath) }

        let packageRecoveryMode: SQLServerRestoreRecoveryMode
        switch recoveryMode {
        case .recovery: packageRecoveryMode = .recovery
        case .noRecovery: packageRecoveryMode = .noRecovery
        case .standby: packageRecoveryMode = .standby
        }

        let options = SQLServerRestoreOptions(
            database: restoreDatabaseName,
            diskPath: restoreDiskPath.trimmingCharacters(in: .whitespaces),
            fileNumber: fileNumber,
            recoveryMode: packageRecoveryMode,
            replace: replace,
            closeExistingConnections: closeConnections,
            keepReplication: keepReplication,
            restrictedUser: restrictedUser,
            checksum: restoreChecksum,
            continueAfterError: restoreContinueOnError,
            relocateFiles: relocations,
            stopAt: usePointInTimeRecovery ? stopAtDate : nil,
            standbyFile: recoveryMode == .standby ? standbyFile : nil
        )
        do {
            guard let adapter = session as? SQLServerSessionAdapter else {
                restorePhase = .failed(message: "Not a SQL Server session")
                handle?.fail("Not a SQL Server session")
                return
            }

            if closeConnections {
                try await adapter.client.backupRestore.closeConnections(database: restoreDatabaseName)
            }

            let messages = try await adapter.client.backupRestore.restore(options: options)
            let infoMessages = messages.filter { $0.kind == .info }.map(\.message)

            if closeConnections {
                try? await adapter.client.backupRestore.restoreMultiUser(database: restoreDatabaseName)
            }

            restorePhase = .completed(messages: infoMessages)
            panelState?.appendMessage("Restore completed for \(restoreDatabaseName).", severity: .success, category: "Restore")
            notificationEngine?.post(.restoreCompleted(database: restoreDatabaseName))
            handle?.succeed()
        } catch {
            if closeConnections {
                guard let adapter = session as? SQLServerSessionAdapter else { return }
                try? await adapter.client.backupRestore.restoreMultiUser(database: restoreDatabaseName)
            }
            restorePhase = .failed(message: error.localizedDescription)
            panelState?.appendMessage("Restore failed: \(error.localizedDescription)", severity: .error, category: "Restore")
            notificationEngine?.post(.restoreFailed(database: restoreDatabaseName, reason: error.localizedDescription))
            handle?.fail(error.localizedDescription)
        }
    }

    func cancelRestore() {
        if isRestoreRunning {
            restorePhase = .failed(message: "Restore cancelled")
        }
    }

    // MARK: - Verify

    func verify() async {
        let path = restoreDiskPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        verifyPhase = .running
        let handle = activityEngine?.begin("Verify backup", connectionSessionID: connectionSessionID)
        do {
            guard let adapter = session as? SQLServerSessionAdapter else {
                verifyPhase = .failed(message: "Not a SQL Server session")
                handle?.fail("Not a SQL Server session")
                return
            }
            let messages = try await adapter.client.backupRestore.verifyBackup(diskPath: path, fileNumber: fileNumber)
            let infoMessages = messages.filter { $0.kind == .info }.map(\.message)
            verifyPhase = .completed(messages: infoMessages)
            handle?.succeed()
        } catch {
            verifyPhase = .failed(message: error.localizedDescription)
            handle?.fail(error.localizedDescription)
        }
    }
}

struct FileRelocationEntry: Identifiable {
    let id = UUID()
    let logicalName: String
    let originalPath: String
    var relocatedPath: String
}
