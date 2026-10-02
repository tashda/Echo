import Foundation

extension EnvironmentState {
    /// Opens saved SQL (a bookmark or a history run) in a new query tab without running it (HP0).
    /// When its server isn't connected, Connect and Open (round IC): it connects first, then opens.
    /// `onOpen` runs on the new tab, for a bookmark to become the tab's home.
    func openSavedQuery(sql: String, connectionID: UUID?, database: String?, onOpen: ((WorkspaceTab) -> Void)? = nil) {
        guard let connectionID else { return }
        if let session = sessionGroup.activeSessions.first(where: { $0.connection.id == connectionID }) {
            open(sql: sql, in: session, database: database, onOpen: onOpen)
            return
        }
        guard let saved = connectionStore.connections.first(where: { $0.id == connectionID }) else { return }
        connect(to: saved)
        Task { @MainActor [weak self] in
            // Waits for the connection like the rail's connect does, up to its own time limit.
            for _ in 0..<600 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let self else { return }
                if let session = self.sessionGroup.activeSessions.first(where: { $0.connection.id == connectionID }) {
                    self.open(sql: sql, in: session, database: database, onOpen: onOpen)
                    return
                }
                if case .error = self.connectionStates[connectionID] { return }
            }
        }
    }

    private func open(sql: String, in session: ConnectionSession, database: String?, onOpen: ((WorkspaceTab) -> Void)?) {
        let before = tabStore.activeTab?.id
        openQueryTab(for: session, presetQuery: sql, autoExecute: false, database: database)
        if let onOpen, let tab = tabStore.activeTab, tab.id != before { onOpen(tab) }
    }

    /// Whether the front tab is a query tab that can take inserted SQL.
    var canInsertIntoActiveEditor: Bool { tabStore.activeTab?.query != nil }

    /// Insert (round IC): puts the SQL at the caret of the front query tab, replacing a selection.
    func insertIntoActiveEditor(_ sql: String) {
        tabStore.activeTab?.query?.editorInsertRequest = EditorInsertRequest(text: sql)
    }
}
