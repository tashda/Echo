import SwiftUI

// MARK: - Global Keyboard Shortcut Handler

struct KeyboardShortcutHandler: ViewModifier {
    @ObservedObject var appModel: AppModel
    @ObservedObject var appState: AppState
    @ObservedObject var shortcutsManager: KeyboardShortcutsManager

    func body(content: Content) -> some View {
        content
            // Server Management Shortcuts
            .background(
                // Invisible buttons to handle keyboard shortcuts
                Button("") {
                    if appModel.sessionManager.activeSessions.count > 1 {
                        appModel.sessionManager.showServerSwitcher()
                    }
                }
                .keyboardShortcut(
                    shortcutsManager.shortcuts.showServerSwitcher.keyEquivalent,
                    modifiers: shortcutsManager.shortcuts.showServerSwitcher.eventModifiers
                )
                .hidden()
            )
            .background(
                Button("") {
                    if appModel.sessionManager.isServerSwitcherVisible {
                        appModel.sessionManager.switchToNextServer()
                    }
                }
                .keyboardShortcut(
                    shortcutsManager.shortcuts.nextServer.keyEquivalent,
                    modifiers: shortcutsManager.shortcuts.nextServer.eventModifiers
                )
                .hidden()
            )
            .background(
                Button("") {
                    if appModel.sessionManager.isServerSwitcherVisible {
                        appModel.sessionManager.switchToPreviousServer()
                    }
                }
                .keyboardShortcut(
                    shortcutsManager.shortcuts.previousServer.keyEquivalent,
                    modifiers: shortcutsManager.shortcuts.previousServer.eventModifiers
                )
                .hidden()
            )
            .background(
                Button("") {
                    appState.showTabOverview.toggle()
                }
                .keyboardShortcut(
                    shortcutsManager.shortcuts.toggleTabOverview.keyEquivalent,
                    modifiers: shortcutsManager.shortcuts.toggleTabOverview.eventModifiers
                )
                .hidden()
            )
    }

    // MARK: - Shortcut Actions

    private func handleConnectToServer() {
        guard let selectedConnection = appModel.selectedConnection else { return }
        Task {
            await appModel.connectToNewSession(to: selectedConnection)
        }
    }

    private func handleDisconnectFromServer() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        Task {
            await appModel.disconnectSession(withID: activeSession.id)
        }
    }

    private func handleNewQueryTab() {
        appModel.openQueryTab()
    }

    private func handleCloseQueryTab() {
        guard let activeTab = appModel.tabManager.activeTab else { return }
        appModel.tabManager.closeTab(id: activeTab.id)
    }

    private func handleExecuteQuery() {
        // This would need to be implemented based on your query execution logic
        // You might need to pass a reference to the current query view
    }

    private func handleRefreshSchema() {
        guard let activeSession = appModel.sessionManager.activeSession else { return }
        Task {
            await appModel.refreshDatabaseStructure(for: activeSession.id)
        }
    }
}

extension View {
    func keyboardShortcutHandler(appModel: AppModel, appState: AppState, shortcutsManager: KeyboardShortcutsManager) -> some View {
        modifier(KeyboardShortcutHandler(appModel: appModel, appState: appState, shortcutsManager: shortcutsManager))
    }
}

// MARK: - Simpler Menu-based Shortcuts

struct MenuKeyboardShortcuts: View {
    @ObservedObject var shortcutsManager: KeyboardShortcutsManager
    let appModel: AppModel
    @ObservedObject var appState: AppState

    var body: some View {
        // This creates invisible menu items that provide keyboard shortcuts
        // They won't be visible but will register the shortcuts
        Group {
            Button("Show Server Switcher") {
                if appModel.sessionManager.activeSessions.count > 1 {
                    appModel.sessionManager.showServerSwitcher()
                }
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.showServerSwitcher.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.showServerSwitcher.eventModifiers
            )
            .hidden()

            Button("New Query Tab") {
                appModel.openQueryTab()
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.newQueryTab.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.newQueryTab.eventModifiers
            )
            .hidden()

            Button("Close Query Tab") {
                appModel.closeActiveQueryTab()
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.closeQueryTab.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.closeQueryTab.eventModifiers
            )
            .disabled(appModel.tabManager.activeTab == nil)
            .hidden()

            Button("Toggle Tab Overview") {
                appState.showTabOverview.toggle()
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.toggleTabOverview.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.toggleTabOverview.eventModifiers
            )
            .hidden()

            Button("Connect to Server") {
                if let selectedConnection = appModel.selectedConnection {
                    Task {
                        await appModel.connectToNewSession(to: selectedConnection)
                    }
                }
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.connectToServer.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.connectToServer.eventModifiers
            )
            .hidden()

            Button("Disconnect from Server") {
                if let activeSession = appModel.sessionManager.activeSession {
                    Task {
                        await activeSession.session.close()
                        appModel.sessionManager.removeSession(withID: activeSession.id)
                    }
                }
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.disconnectFromServer.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.disconnectFromServer.eventModifiers
            )
            .hidden()

            Button("Refresh Schema") {
                if let activeSession = appModel.sessionManager.activeSession {
                    Task {
                        await appModel.refreshDatabaseStructure(for: activeSession.id)
                    }
                }
            }
            .keyboardShortcut(
                shortcutsManager.shortcuts.refreshSchema.keyEquivalent,
                modifiers: shortcutsManager.shortcuts.refreshSchema.eventModifiers
            )
            .hidden()
        }
    }
}
