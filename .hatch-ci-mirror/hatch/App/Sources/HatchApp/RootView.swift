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

/// The project as the window's title control (decision LK2, option D): tile and name; a click opens the list of projects.
struct ProjectTitleMenu: View {
    @EnvironmentObject var state: AppState
    @State private var open = false

    private var current: Project? {
        state.projects.first { $0.key == state.selectedProjectKey }
    }

    var body: some View {
        Button { open.toggle() } label: {
            HStack(spacing: 6) {
                if let p = current {
                    ProjectTile(name: p.name, key: p.key)
                } else {
                    Image(systemName: "square.stack.3d.up").foregroundStyle(.secondary).frame(width: 20, height: 20)
                }
                Text(current?.name ?? "All projects").fontWeight(.semibold)
                Image(systemName: "chevron.down").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .help("Switch project")
        .popover(isPresented: $open, arrowEdge: .bottom) { list }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 2) {
            row(title: "All projects", subtitle: nil, key: nil, name: nil)
            Divider().padding(.vertical, 4)
            ForEach(state.projects) { project in
                row(title: project.name, subtitle: project.config?.repo(.app)?.branch, key: project.key, name: project.name)
            }
            Divider().padding(.vertical, 4)
            Button { open = false; state.route = .projects } label: {
                Label("Project settings…", systemImage: "gearshape").frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8).padding(.vertical, 4)
        }
        .padding(8)
        .frame(minWidth: 240)
    }

    private func row(title: String, subtitle: String?, key: String?, name: String?) -> some View {
        Button {
            state.selectedProjectKey = key
            open = false
        } label: {
            HStack(spacing: 8) {
                if let key, let name { ProjectTile(name: name, key: key) } else { Image(systemName: "square.stack.3d.up").frame(width: 20, height: 20).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                    if let subtitle, !subtitle.isEmpty { Text("branch \(subtitle)").font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                if state.selectedProjectKey == key { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
