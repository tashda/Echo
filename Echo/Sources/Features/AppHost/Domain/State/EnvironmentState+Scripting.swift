import Foundation

extension EnvironmentState {
    /// Opens a query tab with preset SQL for a given connection ID.
    /// Convenience for scripting actions in security/sidebar views.
    func openScriptTab(sql: String, connectionID: UUID) {
        if let session = sessionGroup.sessionForConnection(connectionID) {
            openQueryTab(for: session, presetQuery: sql)
        }
    }
}
