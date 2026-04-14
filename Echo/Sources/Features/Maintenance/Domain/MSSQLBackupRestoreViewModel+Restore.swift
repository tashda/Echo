import Foundation
import SQLServerKit

extension MSSQLBackupRestoreViewModel {

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
}
