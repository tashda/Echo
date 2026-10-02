import SwiftUI

/// Round MC: the middle column. Two-line rows by default (MA1) or a table; connections or
/// identities depending on the sidebar. Double-click connects (MG1).
extension ManageConnectionsView {
    @ViewBuilder
    var contentColumn: some View {
        if activeScope.isConnections {
            if connectionGroups.isEmpty && !isCreatingConnection {
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
            if isCreatingConnection {
                NewConnectionDraftRow()
            }
            ForEach(connectionGroups) { group in
                if let folder = group.folder, let title = group.title {
                    Section(isExpanded: isGroupExpanded(folder.id)) {
                        connectionRows(group.items, duplicates: duplicates, lastUsed: lastUsed)
                    } header: {
                        FolderGroupHeader(title: title, icon: folder.icon, count: group.items.count)
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, kind: .connections, intoFolder: folder.id)
                            }
                    }
                } else {
                    connectionRows(group.items, duplicates: duplicates, lastUsed: lastUsed)
                }
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

    private func connectionRows(_ connections: [SavedConnection], duplicates: Set<String>, lastUsed: [UUID: Date]) -> some View {
        ForEach(connections) { connection in
            ConnectionListRow(
                connection: connection,
                name: displayName(for: connection),
                signIn: signInSummary(for: connection),
                lastUsed: lastUsed[connection.id],
                hasDuplicateName: duplicates.contains(displayName(for: connection).lowercased()),
                color: connectionStore.currentColor(of: connection)
            )
            .tag(connection.id)
            // Drag onto a folder in the sidebar, or onto a folder heading, to file it there.
            .draggable(connection.id.uuidString)
        }
    }

    /// The table's selection: folder rows can't be selected, only connections.
    private var tableConnectionSelection: Binding<Set<UUID>> {
        Binding(
            get: { connectionSelection },
            set: { newValue in
                let connections = newValue.intersection(Set(projectConnections.map(\.id)))
                if connections.isEmpty && !newValue.isEmpty { return }
                navigate(to: .connections(connections))
            }
        )
    }

    private var connectionsTable: some View {
        let duplicates = duplicateConnectionNames
        let lastUsed = lastUsedByConnection
        return Table(of: ConnectionTableItem.self, selection: tableConnectionSelection, sortOrder: $connectionSortOrder) {
            TableColumn("Name", value: \.name) { item in
                switch item {
                case .folder(let folder, let title):
                    Label(title, systemImage: folder.icon)
                        .fontWeight(.semibold)
                        .foregroundStyle(ColorTokens.Text.secondary)
                        .dropDestination(for: String.self) { items, _ in
                            drop(items, kind: .connections, intoFolder: folder.id)
                        }
                case .connection(let connection):
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
            }
            .width(min: 160, ideal: 220, max: 360)

            TableColumn("Engine") { item in
                if let connection = item.connection { EngineLabel(connection: connection) }
            }
            .width(min: 100, ideal: 130, max: 180)

            TableColumn("Server", value: \.host) { item in
                if let connection = item.connection { ServerAddressText(connection: connection) }
            }
            .width(min: 140, ideal: 220, max: 380)

            TableColumn("Sign In") { item in
                if let connection = item.connection { SignInLabel(summary: signInSummary(for: connection)) }
            }
            .width(min: 100, ideal: 150, max: 240)

            TableColumn("Last Used") { item in
                if let connection = item.connection { LastUsedText(date: lastUsed[connection.id]) }
            }
            .width(min: 64, ideal: 84, max: 110)
        } rows: {
            ForEach(connectionGroups) { group in
                if let folder = group.folder, let title = group.title {
                    DisclosureTableRow(ConnectionTableItem.folder(folder, title: title), isExpanded: isGroupExpanded(folder.id)) {
                        ForEach(group.items) { connection in
                            TableRow(ConnectionTableItem.connection(connection))
                        }
                    }
                } else {
                    ForEach(group.items) { connection in
                        TableRow(ConnectionTableItem.connection(connection))
                    }
                }
            }
        }
        .tableStyle(.inset)
        .contextMenu(forSelectionType: UUID.self) { ids in
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
            moveToFolderMenu([connection.id], kind: .connections)
            Divider()
            Button { duplicateConnection(connection) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
            Divider()
            Button(role: .destructive) { pendingDeletion = .connection(connection) } label: { Label("Delete…", systemImage: "trash") }
        } else if !selected.isEmpty {
            moveToFolderMenu(Set(selected.map(\.id)), kind: .connections)
            Divider()
            Button(role: .destructive) { deleteConnections(selected) } label: { Label("Delete \(selected.count) Connections", systemImage: "trash") }
        } else {
            Button { navigate(to: .newConnection) } label: { Label("New Connection…", systemImage: "externaldrive.badge.plus") }
            Button { beginNewFolder(kind: .connections, parentID: currentFolderID) } label: { Label("New Folder…", systemImage: "folder.badge.plus") }
        }
    }

    private var connectionsEmptyState: some View {
        ContentUnavailableView {
            Label(emptyConnectionsTitle, systemImage: normalizedQuery == nil ? "externaldrive" : "magnifyingglass")
        } description: {
            Text(emptyConnectionsMessage)
        } actions: {
            if normalizedQuery == nil && activeScope != .recentConnections {
                Button("New Connection…") { navigate(to: .newConnection) }
            }
        }
    }

    private var emptyConnectionsTitle: String {
        if let query = normalizedQuery { return "No connections match “\(query)”" }
        switch activeScope {
        case .recentConnections: return "Nothing used recently"
        case .folder: return "“\(scopeTitle)” is empty"
        default: return "No connections in \(projectStore.selectedProject?.name ?? "this project") yet"
        }
    }

    private var emptyConnectionsMessage: String {
        if normalizedQuery != nil { return "Search looks at names, servers, databases, user names and identities." }
        switch activeScope {
        case .recentConnections: return "Connections you open appear here for 30 days."
        case .folder: return "Drag connections onto the folder in the sidebar, or choose Move to Folder."
        default: return "Add a server, or paste a connection string into New Connection."
        }
    }

    // MARK: - Identities

    private var identitiesList: some View {
        List(selection: guardedIdentitySelection) {
            ForEach(identityGroups) { group in
                if let folder = group.folder, let title = group.title {
                    Section(isExpanded: isGroupExpanded(folder.id)) {
                        identityRows(group.items)
                    } header: {
                        FolderGroupHeader(title: title, icon: folder.icon, count: group.items.count)
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, kind: .identities, intoFolder: folder.id)
                            }
                    }
                } else {
                    identityRows(group.items)
                }
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: SavedIdentity.ID.self) { ids in
            identityContextMenu(ids)
        }
    }

    private func identityRows(_ identities: [SavedIdentity]) -> some View {
        ForEach(identities) { identity in
            IdentityListRow(identity: identity, usageCount: usageCount(of: identity))
                .tag(identity.id)
                .draggable(identity.id.uuidString)
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
            TableColumn("Folder") { identity in
                Text(connectionStore.folderPath(to: connectionStore.effectiveFolderID(of: identity)).map(\.name).joined(separator: " / "))
                    .foregroundStyle(ColorTokens.Text.secondary)
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
        let selected = connectionStore.identities.filter { ids.contains($0.id) }
        if let identity = selected.first, selected.count == 1 {
            Button { navigate(to: .identities([identity.id])) } label: { Label("Edit", systemImage: "pencil") }
            moveToFolderMenu([identity.id], kind: .identities)
            Divider()
            Button(role: .destructive) { pendingDeletion = .identity(identity) } label: { Label("Delete…", systemImage: "trash") }
        } else if !selected.isEmpty {
            moveToFolderMenu(Set(selected.map(\.id)), kind: .identities)
        } else {
            Button { navigate(to: .newIdentity) } label: { Label("New Identity", systemImage: "person.crop.circle.badge.plus") }
            Button { beginNewFolder(kind: .identities, parentID: currentFolderID) } label: { Label("New Folder…", systemImage: "folder.badge.plus") }
        }
    }

    private var identitiesEmptyState: some View {
        ContentUnavailableView {
            Label(normalizedQuery == nil ? (currentFolderID == nil ? "No identities yet" : "“\(scopeTitle)” is empty") : "No identities match", systemImage: "person.crop.circle")
        } description: {
            Text("An identity is a login that several connections share.")
        } actions: {
            if normalizedQuery == nil {
                Button("New Identity") { navigate(to: .newIdentity) }
            }
        }
    }
}

/// A folder heading in the list (R2-G): the path from the scope, its symbol and a count.
struct FolderGroupHeader: View {
    let title: String
    let icon: String
    let count: Int

    var body: some View {
        HStack(spacing: SpacingTokens.xxs2) {
            Image(systemName: icon)
            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: SpacingTokens.xs)
            Text("\(count)")
                .monospacedDigit()
                .foregroundStyle(ColorTokens.Text.tertiary)
        }
        .contentShape(Rectangle())
    }
}

/// R2-B (NB1): the new connection being made in the pane, at the top of the list. Not
/// selectable; it goes away when the connection is saved or the form is cancelled.
struct NewConnectionDraftRow: View {
    var body: some View {
        HStack(spacing: SpacingTokens.sm) {
            Image(systemName: "plus")
                .font(TypographyTokens.standard.weight(.semibold))
                .foregroundStyle(ColorTokens.accent)
                .frame(width: ConnectionListRowMetrics.markSize, height: ConnectionListRowMetrics.markSize)
                .background(ColorTokens.accent.opacity(0.15), in: Circle())
            Text("New Connection")
                .font(TypographyTokens.standard.weight(.semibold))
                .italic()
            Spacer()
        }
        .padding(.vertical, SpacingTokens.xxxs)
        .listRowBackground(
            RoundedRectangle(cornerRadius: SpacingTokens.xs, style: .continuous)
                .fill(ColorTokens.accent.opacity(0.12))
                .padding(.horizontal, SpacingTokens.xxs)
        )
        .accessibilityLabel("New connection, being edited")
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
