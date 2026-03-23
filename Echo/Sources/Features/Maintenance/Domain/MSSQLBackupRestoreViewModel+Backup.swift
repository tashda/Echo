import Foundation
import SQLServerKit

extension MSSQLBackupRestoreViewModel {

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
}
