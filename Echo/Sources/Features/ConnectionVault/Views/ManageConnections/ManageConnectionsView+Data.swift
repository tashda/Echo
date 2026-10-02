import SwiftUI

extension ManageConnectionsView {
    var selectedProjectID: UUID? { projectStore.selectedProject?.id }

    var projectConnections: [SavedConnection] {
        connectionStore.connections.filter { $0.projectID == selectedProjectID }
    }

    var projectIdentities: [SavedIdentity] {
        connectionStore.identities.filter { $0.projectID == selectedProjectID }
    }

    /// When each connection was last used, from the recent-connection history.
    var lastUsedByConnection: [UUID: Date] {
        var result: [UUID: Date] = [:]
        for record in environmentState.recentConnections {
            if let existing = result[record.id], existing >= record.lastUsedAt { continue }
            result[record.id] = record.lastUsedAt
        }
        return result
    }

    /// Connections used in the last 30 days, newest first.
    var recentConnections: [SavedConnection] {
        let lastUsed = lastUsedByConnection
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        return projectConnections
            .filter { (lastUsed[$0.id] ?? .distantPast) >= cutoff }
            .sorted { (lastUsed[$0.id] ?? .distantPast) > (lastUsed[$1.id] ?? .distantPast) }
    }

    var normalizedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }

    /// The connections of the current scope, searched and sorted.
    var scopedConnections: [SavedConnection] {
        var items: [SavedConnection]
        switch activeScope {
        case .recentConnections:
            items = recentConnections
        case .folder(let folderID):
            // The folder and everything inside it; the list groups them by subfolder.
            let inside = connectionStore.descendantFolderIDs(of: folderID).union([folderID])
            items = sortedConnections(projectConnections.filter {
                connectionStore.effectiveFolderID(of: $0).map(inside.contains) ?? false
            })
        default:
            items = sortedConnections(projectConnections)
        }
        if let query = normalizedQuery {
            items = items.filter { connectionMatches($0, query: query) }
        }
        return items
    }

    /// Sorted the way the table's columns say.
    func sortedConnections(_ connections: [SavedConnection]) -> [SavedConnection] {
        connections.map(ConnectionTableItem.connection).sorted(using: connectionSortOrder).compactMap(\.connection)
    }

    var scopedIdentities: [SavedIdentity] {
        var items = projectIdentities.sorted(using: identitySortOrder)
        if case .identityFolder(let folderID) = activeScope {
            let inside = connectionStore.descendantFolderIDs(of: folderID).union([folderID])
            items = items.filter { connectionStore.effectiveFolderID(of: $0).map(inside.contains) ?? false }
        }
        if let query = normalizedQuery {
            items = items.filter {
                $0.name.lowercased().contains(query) || $0.username.lowercased().contains(query)
            }
        }
        return items
    }

    func connectionMatches(_ connection: SavedConnection, query: String) -> Bool {
        let fields = [
            connection.connectionName, connection.host, connection.database, connection.username,
            connection.databaseType.shortDisplayName, signInSummary(for: connection).text
        ]
        return fields.contains { $0.lowercased().contains(query) }
    }

    /// Names used by more than one connection in the project, lowercased (ME1: marked, not blocked).
    var duplicateConnectionNames: Set<String> {
        var counts: [String: Int] = [:]
        for connection in projectConnections {
            counts[displayName(for: connection).lowercased(), default: 0] += 1
        }
        return Set(counts.filter { $0.value > 1 }.keys)
    }

    func displayName(for connection: SavedConnection) -> String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    /// Who signs in, in words (round MC: never "—" when Echo knows).
    func signInSummary(for connection: SavedConnection) -> SignInSummary {
        SignInSummary(connection: connection, identities: connectionStore.identities)
    }

    /// How many connections sign in with an identity.
    func usageCount(of identity: SavedIdentity) -> Int {
        connectionStore.connections.filter { $0.credentialSource == .identity && $0.identityID == identity.id }.count
    }

    func connections(using identity: SavedIdentity) -> [SavedConnection] {
        connectionStore.connections.filter { $0.credentialSource == .identity && $0.identityID == identity.id }
    }
}

/// What the list and the table say about a connection's sign-in.
struct SignInSummary: Equatable {
    let text: String
    let systemImage: String?
    let isWarning: Bool

    init(connection: SavedConnection, identities: [SavedIdentity]) {
        if connection.databaseType == .sqlite {
            self.init(text: "", systemImage: nil, isWarning: false)
            return
        }
        switch connection.credentialSource {
        case .identity:
            if let identity = identities.first(where: { $0.id == connection.identityID }) {
                self.init(text: identity.name, systemImage: "person.crop.circle", isWarning: false)
            } else {
                self.init(text: "Missing identity", systemImage: "person.crop.circle.badge.exclamationmark", isWarning: true)
            }
        case .manual:
            let user = connection.username.trimmingCharacters(in: .whitespacesAndNewlines)
            switch connection.authenticationMethod {
            case .kerberos:
                self.init(text: "Kerberos ticket", systemImage: "ticket", isWarning: false)
            case .accessToken:
                self.init(text: "Entra token", systemImage: "key", isWarning: false)
            case .windowsIntegrated:
                let domain = connection.domain.trimmingCharacters(in: .whitespacesAndNewlines)
                self.init(text: domain.isEmpty ? user : "\(domain)\\\(user)", systemImage: nil, isWarning: user.isEmpty)
            case .sqlPassword:
                self.init(text: user.isEmpty ? "No user name" : user, systemImage: nil, isWarning: user.isEmpty)
            }
        }
    }

    init(text: String, systemImage: String?, isWarning: Bool) {
        self.text = text
        self.systemImage = systemImage
        self.isWarning = isWarning
    }
}
