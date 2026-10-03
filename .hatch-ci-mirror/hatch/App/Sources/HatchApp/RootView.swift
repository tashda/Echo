import SwiftUI
import HatchCore

/// The window: sidebar, content, and the Ask panel on the right (decisions B1, B4).
struct RootView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            HStack(spacing: 0) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if state.showAskPanel {
                    Divider()
                    AskPanel().frame(width: 320)
                }
            }
            .toolbar { MainToolbar() }
        }
        .sheet(isPresented: $state.showPalette) { CommandPalette() }
        .alert("Something went wrong", isPresented: Binding(get: { state.errorMessage != nil }, set: { if !$0 { state.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(state.errorMessage ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch state.route {
        case .desk: DeskView()
        case .tickets: TicketsView()
        case .board: BoardView()
        case .previews: PreviewsView()
        case .specs: SpecsView()
        case .decisions: DecisionsView()
        case .agents: AgentsView()
        case .log: LogView()
        case .projects: ProjectView()
        case .ticket(let id): TicketDetailView(ticketId: id)
        case .newTicket: ComposerView()
        }
    }
}

struct MainToolbar: ToolbarContent {
    @EnvironmentObject var state: AppState

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { state.showPalette = true } label: { Label("Search", systemImage: "magnifyingglass") }
                .help("Search (⌘K)")
            Button { state.route = .newTicket } label: { Label("New Ticket", systemImage: "plus") }
                .help("New ticket (⌘N)")
            Button { state.showAskPanel.toggle() } label: { Label("Ask", systemImage: "sparkles") }
                .help("Ask Hatch (⌥⌘A)")
        }
    }
}
