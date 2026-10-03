import SwiftUI
import HatchCore

/// Project popup, Work / Reference / Machine sections, sync footer and Project settings (decisions B1, B2, B5, B6).
struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @State private var yourTurn: Int = 0

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
        .safeAreaInset(edge: .top, spacing: 0) {
            ProjectPicker()
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SidebarFooter()
        }
        .autoReload(every: 5) { reloadCounts() }
    }

    private func reloadCounts() {
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

/// "All projects" or one project, shown with its default branch (decision B2).
struct ProjectPicker: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Picker("Project", selection: $state.selectedProjectKey) {
            Text("All projects").tag(String?.none)
            ForEach(state.projects) { project in
                Text(label(for: project)).tag(Optional(project.key))
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func label(for project: Project) -> String {
        if let branch = project.config?.repo(.app)?.branch, !branch.isEmpty {
            return "\(project.name) · \(branch)"
        }
        return project.name
    }
}

/// "Synced with GitHub · 2 pending". Red when something failed. Click opens the Log (decision B5).
struct SidebarFooter: View {
    @EnvironmentObject var state: AppState

    private var summary: AppState.SyncSummary { state.syncSummary }

    private var text: String {
        if summary.failed > 0 {
            return "\(summary.failed) failed to sync · \(summary.pending) pending"
        }
        if summary.pending > 0 {
            return "Synced with GitHub · \(summary.pending) pending"
        }
        return "Synced with GitHub"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider()
            Button {
                state.route = .log
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: summary.failed > 0 ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath")
                        .font(.caption)
                    Text(text)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer()
                }
                .foregroundStyle(summary.failed > 0 ? Theme.critical : Color.secondary)
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
