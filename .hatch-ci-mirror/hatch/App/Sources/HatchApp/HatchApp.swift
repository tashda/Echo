import SwiftUI
import HatchCore

@main
struct HatchApp: App {
    @StateObject private var state = AppState.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .commands { HatchCommands(state: state) }

        Settings {
            SettingsView().environmentObject(state)
        }
    }
}

/// Menu commands and shortcuts from the design: New ticket (cmd-N), Search (cmd-K), Ask (opt-cmd-A).
struct HatchCommands: Commands {
    @ObservedObject var state: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Ticket") { state.route = .newTicket }.keyboardShortcut("n")
        }
        CommandGroup(after: .textEditing) {
            Button("Search") { state.showPalette = true }.keyboardShortcut("k")
            Button("Ask Hatch") { state.showAskPanel.toggle() }.keyboardShortcut("a", modifiers: [.option, .command])
        }
        CommandMenu("Go") {
            Button("Desk") { state.route = .desk }.keyboardShortcut("1")
            Button("Tickets") { state.route = .tickets }.keyboardShortcut("2")
            Button("Board") { state.route = .board }.keyboardShortcut("3")
            Button("Previews") { state.route = .previews }.keyboardShortcut("4")
        }
    }
}
