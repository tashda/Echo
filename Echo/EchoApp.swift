//
//  EchoApp.swift
//  Echo
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI

@main
struct EchoApp: App {
    @StateObject private var coordinator = AppCoordinator.shared
    
    init() {
        FontRegistrar.registerBundledFonts()
    }
    
    var body: some Scene {
        WindowGroup {
            if UITestConfiguration.isRunningQueryEditorDemo {
                QueryEditorUITestHost()
            } else {
                ContentView()
                    .environmentObject(coordinator.appModel)
                    .environmentObject(coordinator.appState)
                    .environmentObject(coordinator.clipboardHistory)
                    .environmentObject(ThemeManager.shared)
                    .task {
                        await coordinator.initialize()
                    }
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
#if os(macOS)
        .commands {
            QueryCommands(appModel: coordinator.appModel, appState: coordinator.appState)
        }
#endif

        Settings {
            SettingsView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(coordinator.clipboardHistory)
                .environmentObject(ThemeManager.shared)
        }
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
#endif
