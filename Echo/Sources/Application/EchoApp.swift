//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI
import AppKit

@main
struct EchoApp: App {
    @StateObject private var coordinator = AppCoordinator.shared

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup("Workspace") {
            WorkspaceView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.appModel.navigationState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(coordinator.themeManager)
                .task { await coordinator.initialize() }
        }
        .commands {
            QueryCommands(appModel: coordinator.appModel,
                          appState: coordinator.appState)
            AppSettingsCommands()
            AutocompleteManagementCommands()
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
#endif
