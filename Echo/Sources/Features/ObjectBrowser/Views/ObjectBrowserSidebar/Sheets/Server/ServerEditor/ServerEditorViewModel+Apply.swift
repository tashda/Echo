import Foundation
import SQLServerKit

// MARK: - Apply Changes

extension ServerEditorViewModel {

    func apply(session: ConnectionSession) async -> Bool {
        guard let adapter = session.session as? SQLServerSessionAdapter else {
            errorMessage = "Server properties are only available for SQL Server connections."
            return false
        }

        isSubmitting = true
        errorMessage = nil
        let serverConfig = adapter.client.serverConfig
        let handle = activityEngine?.begin(
            "Applying server configuration",
            connectionSessionID: connectionSessionID
        )

        do {
            // Apply pending sp_configure changes
            if !pendingChanges.isEmpty {
                let options = pendingChanges.map { (name: $0.key, value: $0.value) }
                _ = try await serverConfig.setConfigurations(options)
            }

            // Apply pending path changes
            if let path = pendingDataPath, path != serverInfo?.instanceDefaultDataPath {
                _ = try await serverConfig.setDefaultDataPath(path)
            }
            if let path = pendingLogPath, path != serverInfo?.instanceDefaultLogPath {
                _ = try await serverConfig.setDefaultLogPath(path)
            }
            if let path = pendingBackupPath, path != serverInfo?.instanceDefaultBackupPath {
                _ = try await serverConfig.setDefaultBackupPath(path)
            }

            handle?.succeed()
            pendingChanges.removeAll()
            pendingDataPath = nil
            pendingLogPath = nil
            pendingBackupPath = nil

            // Reload data to reflect applied changes
            await loadProperties(session: session)
            isSubmitting = false
            return true
        } catch {
            handle?.fail(error.localizedDescription)
            errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }

    func saveAndClose(session: ConnectionSession) async {
        let success = await apply(session: session)
        if success {
            didComplete = true
        }
    }
}
