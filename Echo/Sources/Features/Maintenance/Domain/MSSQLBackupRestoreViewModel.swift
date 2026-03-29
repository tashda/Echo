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

    // Multi-destination & URL support
    var destinationType: BackupDestinationType = .disk
    var destinations: [BackupDestinationEntry] = [BackupDestinationEntry()]
    var credentialName: String = ""

    // Backup scope (database / files / filegroups)
    var backupScope: BackupScopeType = .database
    var databaseFiles: [SelectableDatabaseFile] = []
    var isLoadingFiles = false

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
        guard !databaseName.isEmpty, !isBackupRunning else { return false }

        // At least one destination with a non-empty path
        let hasDestination = destinations.contains { !$0.path.trimmingCharacters(in: .whitespaces).isEmpty }
        guard hasDestination else { return false }

        // URL destinations require a credential name
        if destinationType == .url && credentialName.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }

        // File/filegroup scope requires at least one selected item
        switch backupScope {
        case .database:
            break
        case .files, .filegroups:
            guard databaseFiles.contains(where: \.isSelected) else { return false }
        }

        return true
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
        destinationType = .disk
        destinations = [BackupDestinationEntry()]
        credentialName = ""
        backupScope = .database
        databaseFiles = []
        isLoadingFiles = false
    }

    func loadDatabaseFiles() async {
        guard !isLoadingFiles else { return }
        isLoadingFiles = true
        defer { isLoadingFiles = false }

        do {
            guard let adapter = session as? SQLServerSessionAdapter else { return }
            let files = try await adapter.client.backupRestore.listDatabaseFiles(database: databaseName)
            databaseFiles = files.map { SelectableDatabaseFile(fileInfo: $0) }
        } catch {
            // Silently fail — files list is optional enhancement
            databaseFiles = []
        }
    }

    func addDestination() {
        destinations.append(BackupDestinationEntry())
    }

    func removeDestination(id: UUID) {
        guard destinations.count > 1 else { return }
        destinations.removeAll { $0.id == id }
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
