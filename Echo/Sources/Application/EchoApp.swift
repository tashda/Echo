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
#if os(macOS)
            ConnectMenuCommands(appModel: coordinator.appModel)
#endif
        }

        SettingsWindow()
        AutocompleteManagementWindow()
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

            Button(appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview") {
                appState.showTabOverview.toggle()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Close Query Tab") {
                appModel.closeActiveQueryTab()
            }
            .keyboardShortcut("w", modifiers: [.command])
            .disabled(appModel.tabManager.activeTab == nil)
        }
    }
}

struct AppSettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                openWindow(id: SettingsWindow.sceneID)
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

struct ConnectMenuCommands: Commands {
    @ObservedObject var appModel: AppModel

    var body: some Commands {
        CommandMenu("Connect") {
            let projectID = appModel.selectedProject?.id
            let hasConnections = projectID.flatMap { id in
                appModel.connections.contains(where: { $0.projectID == id })
            } ?? false

            if hasConnections {
                connectionMenuItems(parentID: nil, projectID: projectID)
                Divider()
            } else {
                Text("No Connections Available")
                    .foregroundStyle(.secondary)
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
