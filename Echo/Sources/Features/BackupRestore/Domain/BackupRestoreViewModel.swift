import Foundation
import SQLServerKit

// MARK: - Backup State

enum BackupPhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

@Observable
final class BackupViewModel {
    var databaseName: String
    var backupType: SQLServerBackupType = .full
    var diskPath: String = ""
    var backupName: String = ""
    var compression = false
    var copyOnly = false
    var phase: BackupPhase = .idle

    @ObservationIgnored private let client: SQLServerClient

    init(client: SQLServerClient, databaseName: String) {
        self.client = client
        self.databaseName = databaseName
        self.backupName = "\(databaseName) - Full Backup"
    }

    var isRunning: Bool { phase == .running }

    var canExecute: Bool {
        !diskPath.trimmingCharacters(in: .whitespaces).isEmpty
        && !databaseName.isEmpty
        && !isRunning
    }

    func execute() async {
        guard canExecute else { return }
        phase = .running

        let options = SQLServerBackupOptions(
            database: databaseName,
            diskPath: diskPath.trimmingCharacters(in: .whitespaces),
            backupType: backupType,
            backupName: backupName.isEmpty ? nil : backupName,
            compression: compression,
            copyOnly: copyOnly
        )
        do {
            let messages = try await client.backupRestore.backup(options: options)
            let infoMessages = messages.filter { $0.kind == .info }.map(\.message)
            phase = .completed(messages: infoMessages)
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    func cancel() {
        if isRunning {
            phase = .failed(message: "Backup cancelled")
        }
    }
}

// MARK: - Restore State

enum RestorePhase: Equatable {
    case idle
    case running
    case completed(messages: [String])
    case failed(message: String)
}

@Observable
final class RestoreViewModel {
    var databaseName: String
    var diskPath: String = ""
    var fileNumber: Int = 1
    var withRecovery = true
    var phase: RestorePhase = .idle

    // Backup set listing
    var backupSets: [SQLServerBackupSetInfo] = []
    var backupFiles: [SQLServerBackupFileInfo] = []
    var isLoadingSets = false
    var loadError: String?

    @ObservationIgnored private let client: SQLServerClient

    init(client: SQLServerClient, databaseName: String) {
        self.client = client
        self.databaseName = databaseName
    }

    var isRunning: Bool { phase == .running }

    var canExecute: Bool {
        !diskPath.trimmingCharacters(in: .whitespaces).isEmpty
        && !databaseName.isEmpty
        && !isRunning
    }

    var canListSets: Bool {
        !diskPath.trimmingCharacters(in: .whitespaces).isEmpty && !isLoadingSets
    }

    func listBackupSets() async {
        let path = diskPath.trimmingCharacters(in: .whitespaces)
        guard !path.isEmpty else { return }
        isLoadingSets = true
        loadError = nil
        backupSets = []
        backupFiles = []

        let restoreClient = client.backupRestore
        do {
            let loadedSets = try await restoreClient.listBackupSets(diskPath: path)
            let loadedFiles = try await restoreClient.listBackupFiles(diskPath: path)
            backupSets = loadedSets
            backupFiles = loadedFiles
        } catch {
            loadError = error.localizedDescription
        }
        isLoadingSets = false
    }

    func execute() async {
        guard canExecute else { return }
        phase = .running

        let options = SQLServerRestoreOptions(
            database: databaseName,
            diskPath: diskPath.trimmingCharacters(in: .whitespaces),
            fileNumber: fileNumber,
            withRecovery: withRecovery
        )
        do {
            let messages = try await client.backupRestore.restore(options: options)
            let infoMessages = messages.filter { $0.kind == .info }.map(\.message)
            phase = .completed(messages: infoMessages)
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    func cancel() {
        if isRunning {
            phase = .failed(message: "Restore cancelled")
        }
    }
}
