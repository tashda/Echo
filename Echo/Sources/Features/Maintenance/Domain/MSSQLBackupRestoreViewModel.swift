import Foundation
import SQLServerKit

@Observable
final class MSSQLBackupRestoreViewModel {
    @ObservationIgnored let session: DatabaseSession
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
}
