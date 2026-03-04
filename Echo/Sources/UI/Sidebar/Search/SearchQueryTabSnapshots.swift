import SwiftUI
import EchoSense

@MainActor
func queryTabSnapshots(from workspaceSessionStore: WorkspaceSessionStore?) -> [SearchSidebarQueryTabSnapshot] {
    guard let workspaceSessionStore else { return [] }
    let sessionsByID = Dictionary(uniqueKeysWithValues: workspaceSessionStore.sessionManager.sessions.map { ($0.id, $0) })

    var snapshots: [SearchSidebarQueryTabSnapshot] = []

    for tab in workspaceSessionStore.tabStore.tabs {
        guard let queryState = tab.query else { continue }
        let session = sessionsByID[tab.connectionSessionID]
        let connection = tab.connection
        let trimmedSelectedDatabase = session?.selectedDatabaseName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let databaseName = (trimmedSelectedDatabase?.isEmpty == false ? trimmedSelectedDatabase : nil)
            ?? connection.database.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        let serverText = connectionSummary(for: connection)
        var subtitleComponents: [String] = []
        if !serverText.isEmpty {
            subtitleComponents.append(serverText)
        }
        if let databaseName {
            subtitleComponents.append(databaseName)
        }
        let subtitle = subtitleComponents.isEmpty ? nil : subtitleComponents.joined(separator: " • ")

        snapshots.append(
            SearchSidebarQueryTabSnapshot(
                tabID: tab.id,
                connectionSessionID: tab.connectionSessionID,
                title: tab.title,
                subtitle: subtitle,
                metadata: nil,
                sql: queryState.sql
            )
        )
    }

    return snapshots
}

private func connectionSummary(for connection: SavedConnection) -> String {
    let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
    let host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
    let user = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)

    var userHost: String?
    if !host.isEmpty {
        if !user.isEmpty {
            userHost = "\(user)@\(host)"
        } else {
            userHost = host
        }
    }

    if !name.isEmpty {
        if let userHost {
            return "\(name) (\(userHost))"
        }
        return name
    }

    return userHost ?? "Current Connection"
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
