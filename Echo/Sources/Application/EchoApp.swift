//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

@main
struct EchoApp: App {
    @StateObject private var coordinator = AppCoordinator.shared

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.appModel.navigationState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.themeManager)
                .task { await coordinator.initialize() }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            QueryCommands(appModel: coordinator.appModel,
                          appState: coordinator.appState)
            AppSettingsCommands()
            AutocompleteManagementCommands()
            PerformanceMonitorCommands()
            StreamingTestHarnessCommands()
#if os(macOS)
            ConnectMenuCommands(appModel: coordinator.appModel)
#endif
        }

        AutocompleteManagementWindow()
        PerformanceMonitorWindow()
        StreamingTestHarnessWindow()
    }
}

#if os(macOS)
@MainActor
struct QueryCommands: Commands {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Query Tab") {
                appModel.openQueryTab()
            }
            .keyboardShortcut("t", modifiers: [.command])
            .disabled(!appModel.canOpenQueryTab)

            Button(action: {
                guard appModel.isWorkspaceWindowKey else { return }
                appModel.tabManager.activateNextTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Next Tab")
            }
            .keyboardShortcut(.tab, modifiers: [.control])

            Button(action: {
                guard appModel.isWorkspaceWindowKey else { return }
                appModel.tabManager.activatePreviousTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Previous Tab")
            }
            .keyboardShortcut(.tab, modifiers: [.control, .shift])

            Button(action: {
                guard appModel.isWorkspaceWindowKey else { return }
                if appModel.tabManager.reopenLastClosedTab(activate: true) != nil {
                    if appState.showTabOverview {
                        appState.showTabOverview = false
                    }
                }
            }) {
                Text("Reopen Closed Tab")
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview") {
                appState.showTabOverview.toggle()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Close Query Tab") {
                if appModel.isWorkspaceWindowKey {
                    if appModel.tabManager.activeTab != nil {
                        appModel.closeActiveQueryTab()
                    }
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    keyWindow.performClose(nil)
                }
            }
            .keyboardShortcut("w", modifiers: [.command])
        }
    }
}

struct AppSettingsCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                #if os(macOS)
                SettingsWindowController.shared.present()
                #endif
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct AutocompleteManagementCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Autocomplete Management…") {
                openWindow(id: AutocompleteManagementWindow.sceneID)
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
        }
    }
}

struct PerformanceMonitorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Performance Monitor…") {
                openWindow(id: PerformanceMonitorWindow.sceneID)
            }
            .keyboardShortcut("p", modifiers: [.command, .option])
        }
    }
}

struct StreamingTestHarnessCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Streaming Test Harness…") {
                openWindow(id: StreamingTestHarnessWindow.sceneID)
            }
            .keyboardShortcut("t", modifiers: [.command, .option, .shift])
        }
    }
}

struct ConnectMenuCommands: Commands {
    @ObservedObject var appModel: AppModel

    var body: some Commands {
        CommandMenu("Connect") {
            let projectID = appModel.selectedProject?.id
            let activeSession = prioritizedSession(for: projectID)
            let hasConnections = projectID.flatMap { id in
                appModel.connections.contains(where: { $0.projectID == id })
            } ?? false

            if let activeSession {
                activeSessionMenu(for: activeSession)
                if hasConnections {
                    Divider()
                }
            }

            if hasConnections {
                connectionMenuItems(parentID: nil, projectID: projectID)
            } else if activeSession == nil {
                Text("No Connections Available")
                    .foregroundStyle(.secondary)
            }

            if activeSession != nil || hasConnections {
                Divider()
            }

            Button("Manage Connections…") {
#if os(macOS)
                ManageConnectionsWindowController.shared.present()
#else
                appModel.isManageConnectionsPresented = true
#endif
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }

    private func prioritizedSession(for projectID: UUID?) -> ConnectionSession? {
        if let projectID,
           let active = appModel.sessionManager.activeSession,
           active.connection.projectID == projectID {
            return active
        } else if projectID == nil,
                  let active = appModel.sessionManager.activeSession {
            return active
        }

        let sessions = appModel.sessionManager.sortedSessions
        if let projectID {
            return sessions.first { $0.connection.projectID == projectID }
        }
        return sessions.first
    }

    @ViewBuilder
    private func activeSessionMenu(for session: ConnectionSession) -> some View {
        Menu {
            let databases = availableDatabases(for: session)
            if databases.isEmpty {
                Text("No Databases Available")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(databases, id: \.name) { database in
                    let isSelected = databaseNamesEqual(database.name, session.selectedDatabaseName)
                    Button {
                        selectDatabase(database.name, in: session)
                    } label: {
                        Label {
                            Text(database.name)
                        } icon: {
                            Image(systemName: "checkmark")
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                }
            }
        } label: {
            Label {
                Text(activeSessionLabel(for: session))
            } icon: {
                connectionIcon(for: session.connection)
            }
        }
    }

    private func activeSessionLabel(for session: ConnectionSession) -> String {
        let connectionName = displayName(for: session.connection)
        let selected = trimmedDatabaseName(session.selectedDatabaseName)
        let fallbackDatabase: String? = session.connection.database.isEmpty ? nil : session.connection.database
        if let database = selected ?? trimmedDatabaseName(fallbackDatabase) {
            return "\(connectionName) • \(database)"
        }
        return connectionName
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
            await appModel.loadSchemaForDatabase(databaseName, connectionSession: session)
            await MainActor.run {
                appModel.selectedConnectionID = session.connection.id
                appModel.navigationState.selectDatabase(databaseName)
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
#if os(macOS)
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
#else
        Image(systemName: "externaldrive")
#endif
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
#if os(macOS)
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
#else
                            Image(systemName: "externaldrive")
#endif
                        }
                    }
                }
            }
        )
    }

    private func folders(parentID: UUID?, projectID: UUID?) -> [SavedFolder] {
        guard let projectID else { return [] }
        return appModel.folders
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
        return appModel.connections
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
                appModel.selectedConnectionID = connection.id
                appModel.selectedFolderID = connection.folderID
            }
            await appModel.connect(to: connection)
        }
    }
}
#endif
