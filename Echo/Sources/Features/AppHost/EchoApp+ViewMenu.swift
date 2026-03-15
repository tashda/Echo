//
//  EchoApp+ViewMenu.swift
//  Echo
//

import SwiftUI
#if os(macOS)
import AppKit

struct ViewMenuCommands: Commands {
    var appState: AppState
    let navigationStore: NavigationStore
    let tabStore: TabStore

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button {
                if let keyWindow = NSApplication.shared.keyWindow,
                   keyWindow.identifier == AppWindowIdentifier.manageConnections {
                    NotificationCenter.default.post(name: .toggleManageConnectionsSidebar, object: nil)
                } else {
                    NSApp?.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                }
            } label: {
                Label("Toggle Sidebar", systemImage: "sidebar.left")
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button {
                appState.showInfoSidebar.toggle()
            } label: {
                Label(
                    appState.showInfoSidebar ? "Hide Inspector" : "Show Inspector",
                    systemImage: "sidebar.trailing"
                )
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
            .disabled(!navigationStore.isWorkspaceWindowKey)

            Divider()

            Button {
                appState.showTabOverview.toggle()
            } label: {
                Label(
                    appState.showTabOverview ? "Hide Tab Overview" : "Show Tab Overview",
                    systemImage: "square.grid.2x2"
                )
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(!navigationStore.isWorkspaceWindowKey || !tabStore.hasTabs)
        }
    }
}
#endif
