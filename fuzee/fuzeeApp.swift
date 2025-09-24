//
//  fuzeeApp.swift
//  fuzee
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI

@main
struct FuzeeApp: App {
    @StateObject private var coordinator = AppCoordinator.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator.appModel)
                .environmentObject(coordinator.appState)
                .environmentObject(ThemeManager.shared)
                .task {
                    await coordinator.initialize()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)

        Settings {
            SettingsView().environmentObject(ThemeManager.shared)
        }
    }
}
