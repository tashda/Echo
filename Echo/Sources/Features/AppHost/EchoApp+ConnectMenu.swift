//
//  EchoApp+ConnectMenu.swift
//  Echo
//

import SwiftUI
#if os(macOS)
import AppKit

struct ConnectMenuCommands: Commands {
    @Bindable var environmentState: EnvironmentState
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore

    var body: some Commands {
        CommandMenu("Connect") {
            let projectID = projectStore.selectedProject?.id
            let activeSessions = prioritizedSessions(for: projectID)
            let hasActiveSessions = !activeSessions.isEmpty
            let hasConnections = projectID.flatMap { id in
                connectionStore.connections.contains(where: { $0.projectID == id })
            } ?? false

            if hasActiveSessions {
                ForEach(activeSessions, id: \.id) { session in
                    let isPrimary = session.id == environmentState.sessionGroup.activeSessionID
                    activeSessionMenu(for: session, isPrimary: isPrimary)
                }
            }

            if hasActiveSessions && hasConnections {
                Divider()
            }

            if hasConnections {
                connectionMenuItems(parentID: nil, projectID: projectID)
            } else if !hasActiveSessions {
                Text("No Connections Available")
                    .foregroundStyle(ColorTokens.Text.secondary)
            }

            if hasActiveSessions || hasConnections {
                Divider()
            }

            Button("Manage Connections") {
                ManageConnectionsWindowController.shared.present()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button {
                SparkleUpdater.shared.checkForUpdates()
            } label: {
                Label("Check for Updates", systemImage: "arrow.clockwise.circle")
            }
            .disabled(!SparkleUpdater.shared.canCheckForUpdates)
        }
    }

    private func prioritizedSessions(for projectID: UUID?) -> [ConnectionSession] {
        var sessions = environmentState.sessionGroup.sortedSessions
        guard !sessions.isEmpty else { return [] }

        if let activeID = environmentState.sessionGroup.activeSessionID,
           let index = sessions.firstIndex(where: { $0.id == activeID }) {
            let active = sessions.remove(at: index)
            sessions.insert(active, at: 0)
        }

        guard let projectID else { return sessions }

        var matching: [ConnectionSession] = []
        var others: [ConnectionSession] = []

        for session in sessions {
            if session.connection.projectID == projectID {
                matching.append(session)
            } else {
                others.append(session)
            }
        }

        if matching.isEmpty {
            return sessions
        }
        return matching + others
    }

    @ViewBuilder
    private func activeSessionMenu(for session: ConnectionSession, isPrimary: Bool) -> some View {
        Menu {
            let databases = availableDatabases(for: session)
            if databases.isEmpty {
                Text("No Databases Available")
                    .foregroundStyle(ColorTokens.Text.secondary)
            } else {
                ForEach(databases, id: \.name) { database in
                    let isSelected = databaseNamesEqual(database.name, session.selectedDatabaseName)
                    Button {
                        selectDatabase(database.name, in: session)
                    } label: {
                        databaseMenuLabel(name: database.name, isSelected: isSelected)
                    }
                }
            }
        } label: {
            Label {
                Text(activeSessionLabel(for: session, isPrimary: isPrimary))
            } icon: {
                connectionIcon(for: session.connection)
            }
        }
    }

    private func activeSessionLabel(for session: ConnectionSession, isPrimary: Bool) -> String {
        let connectionName = displayName(for: session.connection)
        let selected = trimmedDatabaseName(session.selectedDatabaseName)
        let fallbackDatabase: String? = session.connection.database.isEmpty ? nil : session.connection.database
        if let database = selected ?? trimmedDatabaseName(fallbackDatabase) {
            let base = "\(connectionName) • \(database)"
            return isPrimary ? "\(base) (Active)" : base
        }
        return isPrimary ? "\(connectionName) (Active)" : connectionName
    }

    @ViewBuilder
    private func databaseMenuLabel(name: String, isSelected: Bool) -> some View {
        let contentWidth: CGFloat = 260
        HStack(spacing: SpacingTokens.xs) {
            if isSelected {
                Image(systemName: "checkmark")
                    .frame(width: 12)
            } else {
                Color.clear
                    .frame(width: 12, height: 12)
            }
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: contentWidth, alignment: .leading)
        .help(name)
    }

    private func availableDatabases(for session: ConnectionSession) -> [DatabaseInfo] {
        let source = session.databaseStructure?.databases ?? session.connection.cachedStructure?.databases ?? []
        var deduplicated: [DatabaseInfo] = []
        var seen: Set<String> = []

        for database in source {
            let key = normalizedDatabaseName(database.name) ?? database.name.lowercased()
            if seen.insert(key).inserted {
                deduplicated.append(database)
            }
        }

        return deduplicated.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func selectDatabase(_ databaseName: String, in session: ConnectionSession) {
        guard !databaseNamesEqual(databaseName, session.selectedDatabaseName) else { return }
        Task {
            await MainActor.run {
                environmentState.sessionGroup.setActiveSession(session.id)
                connectionStore.selectedConnectionID = session.connection.id
                navigationStore.navigationState.selectConnection(session.connection)
                navigationStore.navigationState.selectDatabase(databaseName)
            }
            await environmentState.loadSchemaForDatabase(databaseName, connectionSession: session)
            await MainActor.run {
                connectionStore.selectedConnectionID = session.connection.id
                navigationStore.navigationState.selectConnection(session.connection)
                navigationStore.navigationState.selectDatabase(databaseName)
            }
        }
    }

    private func databaseNamesEqual(_ lhs: String?, _ rhs: String?) -> Bool {
        normalizedDatabaseName(lhs) == normalizedDatabaseName(rhs)
    }

    private func normalizedDatabaseName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed.lowercased()
    }

    private func trimmedDatabaseName(_ name: String?) -> String? {
        guard let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    @ViewBuilder
    private func connectionIcon(for connection: SavedConnection) -> some View {
        if let logoData = connection.logo,
           let nsImage = NSImage(data: logoData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        } else {
            Image(connection.databaseType.iconName)
                .resizable()
                .renderingMode(.template)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
        }
    }

    private func connectionMenuItems(parentID: UUID?, projectID: UUID?) -> AnyView {
        let folders = foldersWithContent(parentID: parentID, projectID: projectID)
        let connections = connections(parentID: parentID, projectID: projectID)

        return AnyView(
            Group {
                ForEach(folders, id: \.id) { folder in
                    Menu(folder.name) {
                        connectionMenuItems(parentID: folder.id, projectID: projectID)
                    }
                }

                ForEach(connections, id: \.id) { connection in
                    Button {
                        connect(to: connection)
                    } label: {
                        Label {
                            Text(displayName(for: connection))
                        } icon: {
                            if let logoData = connection.logo,
                               let nsImage = NSImage(data: logoData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                            } else {
                                Image(connection.databaseType.iconName)
                                    .resizable()
                                    .renderingMode(.template)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 14, height: 14)
                            }
                        }
                    }
                }
            }
        )
    }

    private func folders(parentID: UUID?, projectID: UUID?) -> [SavedFolder] {
        guard let projectID else { return [] }
        return connectionStore.folders
            .filter { $0.kind == .connections && $0.projectID == projectID && $0.parentFolderID == parentID }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func foldersWithContent(parentID: UUID?, projectID: UUID?) -> [SavedFolder] {
        folders(parentID: parentID, projectID: projectID)
            .filter { folderHasContent($0.id, projectID: projectID) }
    }

    private func folderHasContent(_ folderID: UUID, projectID: UUID?) -> Bool {
        !connections(parentID: folderID, projectID: projectID).isEmpty ||
            folders(parentID: folderID, projectID: projectID).contains {
                folderHasContent($0.id, projectID: projectID)
            }
    }

    private func connections(parentID: UUID?, projectID: UUID?) -> [SavedConnection] {
        guard let projectID else { return [] }
        return connectionStore.connections
            .filter { $0.projectID == projectID && $0.folderID == parentID }
            .sorted { displayName(for: $0).localizedCaseInsensitiveCompare(displayName(for: $1)) == .orderedAscending }
    }

    private func displayName(for connection: SavedConnection) -> String {
        let name = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? connection.host : name
    }

    private func connect(to connection: SavedConnection) {
        Task {
            await MainActor.run {
                connectionStore.selectedConnectionID = connection.id
                connectionStore.selectedFolderID = connection.folderID
                navigationStore.navigationState.selectConnection(connection)
            }
            environmentState.connect(to: connection)
        }
    }
}
#endif
