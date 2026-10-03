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
            .navigationTitle(state.route.title)
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
        ToolbarItem(placement: .navigation) { ProjectTitleMenu() }
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

/// The project as the window's title menu (decision LK2, option D): tile, name and a pull-down with every project.
struct ProjectTitleMenu: View {
    @EnvironmentObject var state: AppState

    private var current: Project? {
        state.projects.first { $0.key == state.selectedProjectKey }
    }

    var body: some View {
        Menu {
            Button { state.selectedProjectKey = nil } label: {
                if state.selectedProjectKey == nil { Label("All projects", systemImage: "checkmark") } else { Text("All projects") }
            }
            Divider()
            ForEach(state.projects) { project in
                Button { state.selectedProjectKey = project.key } label: {
                    let branch = project.config?.repo(.app)?.branch ?? ""
                    let name = branch.isEmpty ? project.name : "\(project.name) · \(branch)"
                    if project.key == state.selectedProjectKey { Label(name, systemImage: "checkmark") } else { Text(name) }
                }
            }
            Divider()
            Button("Project settings…") { state.route = .projects }
        } label: {
            HStack(spacing: 6) {
                if let p = current { ProjectTile(name: p.name, key: p.key) } else { Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary) }
                Text(current?.name ?? "All projects").fontWeight(.semibold)
            }
        }
        .menuIndicator(.visible)
        .help("Switch project")
    }
}
