import SwiftUI
import HatchCore

/// Work / Views / Reference / Machine sections, sync footer and Project settings (decisions B1, B5, D3).
/// The project switch is the toolbar title control (LK2), not a popup here.
struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @State private var yourTurn: Int = 0
    @State private var views: [SavedView] = []
    /// Read by TicketsView, which applies it as its filter (decision D3).
    @AppStorage("hatch.pendingTicketQuery") private var pendingQuery = ""

    private var selection: Binding<Route?> {
        Binding<Route?>(
            get: { Self.sidebarRoute(for: state.route) },
            set: { newValue in
                if let newValue { state.route = newValue }
            }
        )
    }

    /// A ticket page or the composer highlights nothing; the other routes highlight themselves.
    private static func sidebarRoute(for route: Route) -> Route? {
        switch route {
        case .ticket, .newTicket: return nil
        default: return route
        }
    }

    var body: some View {
        List(selection: selection) {
            Section("Work") {
                deskRow
                SidebarRow(route: .tickets).tag(Route.tickets)
                SidebarRow(route: .board).tag(Route.board)
                SidebarRow(route: .previews).tag(Route.previews)
            }
            if !views.isEmpty {
                Section("Views") {
                    ForEach(views) { view in
                        Button {
                            pendingQuery = view.query
                            state.route = .tickets
                        } label: {
                            Label(view.name, systemImage: "bookmark")
                        }
                        .buttonStyle(.plain)
                        .help(view.query)
                    }
                }
            }
            Section("Reference") {
                SidebarRow(route: .specs).tag(Route.specs)
                SidebarRow(route: .decisions).tag(Route.decisions)
            }
            Section("Machine") {
                SidebarRow(route: .agents).tag(Route.agents)
                SidebarRow(route: .log).tag(Route.log)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
        .autoReload(every: 5) { reloadCounts() }
        .onAppear { reloadViews() }
    }

    /// The same saved views the Tickets screen keeps; the built-in ones show until the owner saves their own.
    private func reloadViews() {
        guard let json = (try? state.store.setting("views")) ?? nil,
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([SavedView].self, from: data) else {
            if views != TicketsView.defaultViews { views = TicketsView.defaultViews }
            return
        }
        if views != decoded { views = decoded }
    }

    private func reloadCounts() {
        reloadViews()
        let count = state.yourTurnCount
        if count != yourTurn { yourTurn = count }
        let counts = (try? state.store.syncCounts()) ?? (pending: 0, failed: 0)
        if counts.pending != state.syncSummary.pending || counts.failed != state.syncSummary.failed {
            state.refreshSyncSummary()
        }
    }

    private var deskRow: some View {
        HStack {
            Label(Route.desk.title, systemImage: Route.desk.symbol)
            Spacer()
            if yourTurn > 0 {
                Text("\(yourTurn)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.you)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 1)
                    .background(Theme.youBackground, in: Capsule())
            }
        }
        .tag(Route.desk)
    }
}

struct SidebarRow: View {
    let route: Route

    var body: some View {
        Label(route.title, systemImage: route.symbol)
            .tag(route)
    }
}

/// "Synced with GitHub · 2 pending". Red when something failed. Click opens the Log (decision B5).
struct SidebarFooter: View {
    @EnvironmentObject var state: AppState

    private var summary: AppState.SyncSummary { state.syncSummary }

    private var text: String {
        if let message = summary.message, !message.isEmpty { return message }
        if summary.failed > 0 {
            return "\(summary.failed) failed to sync · \(summary.pending) pending"
        }
        if summary.pending > 0 {
            return "Syncing with GitHub · \(summary.pending) pending"
        }
        if summary.lastOK == nil { return "Not synced yet" }
        return "Synced with GitHub"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Button {
                state.route = .log
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: (summary.failed > 0 || summary.message != nil) ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text(text)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle((summary.failed > 0 || summary.message != nil) ? Theme.critical : Color.secondary)
            }
            .buttonStyle(.plain)
            .help("Open the Log")
            Button {
                state.route = .projects
            } label: {
                Label("Project settings", systemImage: Route.projects.symbol)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }
}
