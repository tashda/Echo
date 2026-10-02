import SwiftUI

/// Round MC: the middle column. Two-line rows by default (MA1) or a table; connections or
/// identities depending on the sidebar. Double-click connects (MG1).
extension ManageConnectionsView {
    @ViewBuilder
    var contentColumn: some View {
        if activeScope.isConnections {
            if scopedConnections.isEmpty {
                connectionsEmptyState
            } else if viewMode == .table {
                connectionsTable
            } else {
                connectionsList
            }
        } else {
            if scopedIdentities.isEmpty {
                identitiesEmptyState
            } else if viewMode == .table {
                identitiesTable
            } else {
                identitiesList
            }
        }
    }

    internal var guardedConnectionSelection: Binding<Set<SavedConnection.ID>> {
        Binding(get: { connectionSelection }, set: { navigate(to: .connections($0)) })
    }

    internal var guardedIdentitySelection: Binding<Set<SavedIdentity.ID>> {
        Binding(get: { identitySelection }, set: { navigate(to: .identities($0)) })
    }

    // MARK: - Connections

    private var connectionsList: some View {
        let duplicates = duplicateConnectionNames
        let lastUsed = lastUsedByConnection
        return List(selection: guardedConnectionSelection) {
            ForEach(scopedConnections) { connection in
                ConnectionListRow(
                    connection: connection,
                    name: displayName(for: connection),
                    signIn: signInSummary(for: connection),
                    lastUsed: lastUsed[connection.id],
                    hasDuplicateName: duplicates.contains(displayName(for: connection).lowercased()),
                    color: connectionStore.currentColor(of: connection)
                )
                .tag(connection.id)
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: SavedConnection.ID.self) { ids in
            connectionContextMenu(ids)
        } primaryAction: { ids in
            if let id = ids.first, let connection = connectionStore.connections.first(where: { $0.id == id }) {
                connectToConnection(connection)
            }
        }
    }

    private var connectionsTable: some View {
        let duplicates = duplicateConnectionNames
        let lastUsed = lastUsedByConnection
        return Table(scopedConnections, selection: guardedConnectionSelection, sortOrder: $connectionSortOrder) {
            TableColumn("Name", value: \.connectionName) { connection in
                HStack(spacing: SpacingTokens.xs) {
                    ServerRailMark(
                        monogram: ServerRailMonogram.make(from: displayName(for: connection)),
                        glyph: connection.railGlyph,
                        color: connectionStore.currentColor(of: connection),
                        weight: .bold,
                        size: SpacingTokens.lg
                    )
                    .accessibilityHidden(true)
                    Text(displayName(for: connection))
                        .lineLimit(1)
                    if duplicates.contains(displayName(for: connection).lowercased()) {
                        DuplicateNameDot()
                    }
                }
            }
            .width(min: 140, ideal: 200, max: 340)

            TableColumn("Engine") { connection in
                EngineLabel(connection: connection)
            }
            .width(min: 100, ideal: 130, max: 180)

            TableColumn("Server", value: \.host) { connection in
                ServerAddressText(connection: connection)
            }
            .width(min: 140, ideal: 220, max: 380)

            TableColumn("Sign In") { connection in
                SignInLabel(summary: signInSummary(for: connection))
            }
            .width(min: 100, ideal: 150, max: 240)

            TableColumn("Last Used") { connection in
                LastUsedText(date: lastUsed[connection.id])
            }
            .width(min: 64, ideal: 84, max: 110)
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: SavedConnection.ID.self) { ids in
            connectionContextMenu(ids)
        } primaryAction: { ids in
            if let id = ids.first, let connection = connectionStore.connections.first(where: { $0.id == id }) {
                connectToConnection(connection)
            }
        }
    }

    @ViewBuilder
    private func connectionContextMenu(_ ids: Set<SavedConnection.ID>) -> some View {
        let selected = connectionStore.connections.filter { ids.contains($0.id) }
        if let connection = selected.first, selected.count == 1 {
            Button { connectToConnection(connection) } label: { Label("Connect", systemImage: "bolt.horizontal") }
            Button { navigate(to: .connections([connection.id])) } label: { Label("Edit", systemImage: "pencil") }
            Divider()
            Button { duplicateConnection(connection) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive) { pendingDeletion = .connection(connection) } label: { Label("Delete…", systemImage: "trash") }
        } else if !selected.isEmpty {
            Button(role: .destructive) { deleteConnections(selected) } label: { Label("Delete \(selected.count) Connections", systemImage: "trash") }
        } else {
            Button { navigate(to: .newConnection) } label: { Label("New Connection…", systemImage: "externaldrive.badge.plus") }
        }
    }

    private var connectionsEmptyState: some View {
        ContentUnavailableView {
            Label(emptyConnectionsTitle, systemImage: normalizedQuery == nil ? "externaldrive" : "magnifyingglass")
        } description: {
            Text(emptyConnectionsMessage)
        } actions: {
            if normalizedQuery == nil && activeScope == .allConnections {
                Button("New Connection…") { navigate(to: .newConnection) }
            }
        }
    }

    private var emptyConnectionsTitle: String {
        if let query = normalizedQuery { return "No connections match “\(query)”" }
        return activeScope == .recentConnections ? "Nothing used recently" : "No connections in \(projectStore.selectedProject?.name ?? "this project") yet"
    }

    private var emptyConnectionsMessage: String {
        if normalizedQuery != nil { return "Search looks at names, servers, databases, user names and identities." }
        return activeScope == .recentConnections ? "Connections you open appear here for 30 days." : "Add a server, or paste a connection string into New Connection."
    }

    // MARK: - Identities

    private var identitiesList: some View {
        List(selection: guardedIdentitySelection) {
            ForEach(scopedIdentities) { identity in
                IdentityListRow(identity: identity, usageCount: usageCount(of: identity))
                    .tag(identity.id)
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: SavedIdentity.ID.self) { ids in
            identityContextMenu(ids)
        }
    }

    private var identitiesTable: some View {
        Table(scopedIdentities, selection: guardedIdentitySelection, sortOrder: $identitySortOrder) {
            TableColumn("Name", value: \.name) { identity in
                Label(identity.name, systemImage: "person.crop.circle")
            }
            .width(min: 120, ideal: 180, max: 300)
            TableColumn("Signs In As", value: \.username) { identity in
                Text(identity.signInName).foregroundStyle(ColorTokens.Text.secondary)
            }
            TableColumn("Kind") { identity in
                Text(identity.authenticationMethod.displayName).foregroundStyle(ColorTokens.Text.secondary)
            }
            TableColumn("Used By") { identity in
                let count = usageCount(of: identity)
                Text(count == 0 ? "Not used" : (count == 1 ? "1 connection" : "\(count) connections"))
                    .foregroundStyle(count == 0 ? ColorTokens.Text.tertiary : ColorTokens.Text.secondary)
            }
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: SavedIdentity.ID.self) { ids in
            identityContextMenu(ids)
        }
    }

    @ViewBuilder
    private func identityContextMenu(_ ids: Set<SavedIdentity.ID>) -> some View {
        if let id = ids.first, let identity = connectionStore.identities.first(where: { $0.id == id }) {
            Button(role: .destructive) { pendingDeletion = .identity(identity) } label: { Label("Delete…", systemImage: "trash") }
        } else {
            Button { navigate(to: .newIdentity) } label: { Label("New Identity", systemImage: "person.crop.circle.badge.plus") }
        }
    }

    private var identitiesEmptyState: some View {
        ContentUnavailableView {
            Label(normalizedQuery == nil ? "No identities yet" : "No identities match", systemImage: "person.crop.circle")
        } description: {
            Text("An identity is a login that several connections share.")
        } actions: {
            if normalizedQuery == nil {
                Button("New Identity") { navigate(to: .newIdentity) }
            }
        }
    }
}

extension SavedIdentity {
    /// The user name, or DOMAIN\user for a Windows account.
    var signInName: String {
        let user = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if authenticationMethod == .accessToken { return "Token" }
        if let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty {
            return "\(domain)\\\(user)"
        }
        return user
    }
}
