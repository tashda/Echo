import Foundation

extension EnvironmentState {
    func openSavedQuery(sql: String, connectionID: UUID?, database: String?) {
        guard let connectionID,
              let session = sessionGroup.activeSessions.first(where: { $0.connection.id == connectionID }) else { return }
        openQueryTab(for: session, presetQuery: sql, autoExecute: false, database: database)
    }
}
