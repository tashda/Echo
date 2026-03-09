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
        #if os(macOS)
        if let forced = ProcessInfo.processInfo.environment["ECHO_FORCE_APPEARANCE"] {
            switch forced.lowercased() {
            case "dark":
                NSApp?.appearance = NSAppearance(named: .darkAqua)
            case "light":
                NSApp?.appearance = NSAppearance(named: .aqua)
            default:
                break
            }
        }
        #endif
    }

    var body: some Scene {
        SwiftUI.WindowGroup {
            WorkspaceView()
                .environment(coordinator.projectStore)
                .environment(coordinator.connectionStore)
                .environment(coordinator.navigationStore)
                .environment(coordinator.tabStore)
                .environment(coordinator.resultSpoolConfigCoordinator)
                .environment(coordinator.diagramCoordinator)
                .environmentObject(coordinator.navigationStore.navigationState)
                .environmentObject(coordinator.environmentState)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.appearanceStore)
                .task { await coordinator.initialize() }
        }
        .defaultLaunchBehavior(.presented)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands {
            QueryCommands(
                environmentState: coordinator.environmentState,
                appState: coordinator.appState,
                navigationStore: coordinator.navigationStore,
                tabStore: coordinator.tabStore,
                projectStore: coordinator.projectStore
            )
            AppSettingsCommands()
            AutocompleteInspectorCommands()
            PerformanceMonitorCommands()
            StreamingTestHarnessCommands()
            SparkleCommands()
#if os(macOS)
            ConnectMenuCommands(
                environmentState: coordinator.environmentState,
                projectStore: coordinator.projectStore,
                connectionStore: coordinator.connectionStore,
                navigationStore: coordinator.navigationStore
            )
#endif
        }
        AutocompleteInspectorWindow()
        PerformanceMonitorWindow()
        StreamingTestHarnessWindow()
        SettingsWindowScene()
    }
}

#if os(macOS)
@MainActor
struct QueryCommands: Commands {
    @ObservedObject var environmentState: EnvironmentState
    @ObservedObject var appState: AppState
    let navigationStore: NavigationStore
    let tabStore: TabStore
    let projectStore: ProjectStore

    private var customShortcuts: [String: CustomShortcutBinding] {
        projectStore.globalSettings.customKeyboardShortcuts ?? [:]
    }

    private func key(for title: String, default defaultKey: KeyEquivalent) -> KeyEquivalent {
        customShortcuts[title]?.swiftUIKey ?? defaultKey
    }

    private func mods(for title: String, default defaultMods: EventModifiers) -> EventModifiers {
        customShortcuts[title]?.swiftUIModifiers ?? defaultMods
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("New Query Tab") {
                environmentState.openQueryTab()
            }
            .keyboardShortcut(key(for: "New Query Tab", default: "t"), modifiers: mods(for: "New Query Tab", default: [.command]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activateNextTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Next Tab")
            }
            .keyboardShortcut(key(for: "Next Tab", default: .tab), modifiers: mods(for: "Next Tab", default: [.control]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                tabStore.activatePreviousTab()
                if appState.showTabOverview {
                    appState.showTabOverview = false
                }
            }) {
                Text("Previous Tab")
            }
            .keyboardShortcut(key(for: "Previous Tab", default: .tab), modifiers: mods(for: "Previous Tab", default: [.control, .shift]))

            Button(action: {
                guard navigationStore.isWorkspaceWindowKey else { return }
                if tabStore.reopenLastClosedTab(activate: true) != nil {
                    if appState.showTabOverview {
                        appState.showTabOverview = false
                    }
                }
            }) {
                Text("Reopen Closed Tab")
            }
            .keyboardShortcut(key(for: "Reopen Closed Tab", default: "t"), modifiers: mods(for: "Reopen Closed Tab", default: [.command, .shift]))

            Button(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview") {
                appState.showTabOverview.toggle()
            }
            .keyboardShortcut(key(for: "Show Tab Overview", default: "o"), modifiers: mods(for: "Show Tab Overview", default: [.command]))

            Button("Close Query Tab") {
                if navigationStore.isWorkspaceWindowKey {
                    if let active = tabStore.activeTab {
                        tabStore.closeTab(id: active.id)
                    }
                } else if let keyWindow = NSApplication.shared.keyWindow {
                    keyWindow.performClose(nil)
                }
            }
            .keyboardShortcut(key(for: "Close Query Tab", default: "w"), modifiers: mods(for: "Close Query Tab", default: [.command]))
        }
    }
}

struct AutocompleteInspectorCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Autocomplete Management…") {
                openWindow(id: AutocompleteInspectorWindow.sceneID)
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

struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: SettingsWindowScene.sceneID)
            }
            .keyboardShortcut(",", modifiers: [.command])
        }
    }
}

struct SparkleCommands: Commands {
    @StateObject private var updater = SparkleUpdater.shared

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updater.checkForUpdates()
            }
            .disabled(!updater.canCheckForUpdates)
        }
    }
}

struct ConnectMenuCommands: Commands {
    @ObservedObject var environmentState: EnvironmentState
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
                    let isPrimary = session.id == environmentState.sessionCoordinator.activeSessionID
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
                    .foregroundStyle(.secondary)
            }

            if hasActiveSessions || hasConnections {
                Divider()
            }

            Button("Manage Connections…") {
#if os(macOS)
                ManageConnectionsWindowController.shared.present()
#else
                navigationStore.isManageConnectionsPresented = true
#endif
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
        }
    }

    private func prioritizedSessions(for projectID: UUID?) -> [ConnectionSession] {
        var sessions = environmentState.sessionCoordinator.sortedSessions
        guard !sessions.isEmpty else { return [] }

        if let activeID = environmentState.sessionCoordinator.activeSessionID,
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
                    .foregroundStyle(.secondary)
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
        HStack(spacing: 8) {
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
                environmentState.sessionCoordinator.setActiveSession(session.id)
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
            await environmentState.connect(to: connection)
        }
    }
}
#endif
