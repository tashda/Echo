import Foundation

/// Switching a tab's database, shared by the footer chip, the tab strip and the ⌘K palette.
extension EnvironmentState {
    /// The online databases of the tab's server, sorted by name.
    func switchableDatabaseNames(for tab: WorkspaceTab) -> [String] {
        guard tab.connection.databaseType != .sqlite,
              let session = sessionGroup.activeSessions.first(where: { $0.id == tab.connectionSessionID }) else { return [] }
        let databases = session.databaseStructure?.databases ?? []
        return databases.filter(\.isOnline).map(\.name)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Points the tab at another database. SQL Server and MySQL reuse the connection; Postgres gets
    /// a session per database, cached by its server connection.
    func switchDatabase(_ databaseName: String, for tab: WorkspaceTab) {
        guard tab.connection.databaseType != .sqlite else { return }
        Task {
            do {
                _ = try await tab.session.sessionForDatabase(databaseName)
                tab.activeDatabaseName = databaseName
                if let queryState = tab.query {
                    queryState.updateClipboardContext(
                        serverName: queryState.clipboardMetadata.serverName,
                        databaseName: databaseName,
                        connectionColorHex: queryState.clipboardMetadata.connectionColorHex
                    )
                }
                notificationEngine?.post(category: .databaseSwitched, message: "Switched to \(databaseName)")
            } catch {
                notificationEngine?.post(
                    category: .databaseSwitchFailed,
                    message: "Failed to switch: \(error.localizedDescription)",
                    duration: 5.0
                )
            }
        }
    }
}
