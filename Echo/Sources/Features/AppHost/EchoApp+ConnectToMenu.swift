import SwiftUI
#if os(macOS)

/// File › Connect To (round 52, SM1 and KB1). The + in the server rail opens the trail into a
/// searchable list; this menu keeps the list as a system menu for the menu bar, and ⇧⌘K opens the
/// trail with its search field focused (Return connects the first match, Escape closes).
struct ConnectToCommands: Commands {
    let appState: AppState
    let environmentState: EnvironmentState
    let projectStore: ProjectStore
    let connectionStore: ConnectionStore
    let navigationStore: NavigationStore

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button {
                guard navigationStore.isWorkspaceWindowKey else { return }
                appState.isConnectTrailOpen.toggle()
            } label: {
                Label("Connect to a Server", systemImage: "plus.circle")
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])

            Menu {
                ConnectionsMenuContent()
                    .environment(projectStore)
                    .environment(connectionStore)
                    .environment(environmentState)
            } label: {
                Label("Connect To", systemImage: "cable.connector")
            }
        }
    }
}
#endif
