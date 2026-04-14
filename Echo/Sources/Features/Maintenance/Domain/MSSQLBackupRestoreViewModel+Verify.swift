import Foundation
import SQLServerKit

extension MSSQLBackupRestoreViewModel {

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
