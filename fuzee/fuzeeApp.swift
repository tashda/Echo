//
//  fuzeeApp.swift
//  fuzee
//
//  Created by Kenneth Berg on 15/09/2025.
//

import SwiftUI

@main
struct fuzeeApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel).environmentObject(appState).alert("Database Error",
                isPresented: $appState.showingError,
                presenting: appState.currentError) {
                error in
                Button("OK") {
                    appState.clearError()
                }
            } message: {
                error in
                Text(error.localizedDescription)
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
