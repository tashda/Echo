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
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        FontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        SettingsWindow()
            .commands {
                QueryCommands(appModel: AppCoordinator.shared.appModel,
                              appState: AppCoordinator.shared.appState)
                AppSettingsCommands()
            }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await AppCoordinator.shared.initialize()
            AppCoordinator.shared.openInitialWorkspaceIfNeeded()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            AppCoordinator.shared.reopenLastWindow()
        }
        return true
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
#endif
