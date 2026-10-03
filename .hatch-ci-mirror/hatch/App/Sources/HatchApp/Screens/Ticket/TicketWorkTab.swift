import SwiftUI
import AppKit
import HatchCore

/// Work: who is working, the build steps, the workspaces and branches, and the files claimed (decisions I1, K3).
struct TicketWorkTab: View {
    let ticket: Ticket
    @EnvironmentObject var state: AppState

    @State private var workspaces: [Workspace] = []
    @State private var repos: [Repo] = []
    @State private var claims: [Claim] = []
    @State private var blockers: [Ticket] = []

    private var showsBuildSteps: Bool {
        ticket.type == .proposal || ticket.type == .tweak || ticket.type == .bug
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                agentRow
                if !blockers.isEmpty { blockerCard }
                if showsBuildSteps { buildSection }
                workspaceSection
                claimSection
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .autoReload(every: 5) { load() }
    }

    // MARK: Agent

    private var agentRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "cpu").foregroundStyle(ticket.takenBy == nil ? Color.secondary : Theme.agent)
            if let who = ticket.takenBy {
                Text("\(who) is working on this")
                Spacer()
                Button("Stop agent") { stopAgent() }
                    .help("Takes the ticket back from the agent. The agent finds out the next time it asks Hatch.")
            } else {
                Text("No agent is working on this right now.")
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private func stopAgent() {
        let id = ticket.id
        _ = state.perform("Could not stop the agent") { try state.store.release(id, reason: "stopped by the owner") }
    }

    private var blockerCard: some View {
        SectionCard("Waiting for") {
            ForEach(blockers) { other in
                Button {
                    state.open(other)
                } label: {
                    HStack(spacing: 8) {
                        Text(other.displayNumber).foregroundStyle(.secondary)
                        Text(other.title)
                        StatusChip(status: other.status)
                    }
                }
                .buttonStyle(.link)
            }
        }
    }

    // MARK: Build steps (another agent's view)

    private var buildSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Build steps")
                .font(.headline)
            // The steps view belongs to the build module; it reads the ticket's events itself.
            BuildStepsView(ticketId: ticket.id)
        }
    }

    // MARK: Workspaces

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspaces and branches")
                .font(.headline)
            if workspaces.isEmpty {
                plannedBranches
            } else {
                ForEach(workspaces) { ws in
                    workspaceRow(ws)
                }
            }
        }
    }

    private func repoLabel(_ id: Int) -> String {
        guard let repo = repos.first(where: { $0.id == id }) else { return "Repo" }
        switch repo.role {
        case .app: return "App"
        case .designSystem: return "Design system"
        case .specimens: return "Specimens"
        case .tickets: return "Tickets"
        }
    }

    private func workspaceRow(_ ws: Workspace) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(repoLabel(ws.repoId))
                    .font(.callout.weight(.semibold))
                Text(ws.branch)
                    .font(.callout.monospaced())
                PlainChip(text: ws.state)
                Spacer()
                Button("Open in Terminal") { openTerminal(ws.path) }
                    .controlSize(.small)
                Button("Show in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: ws.path)
                }
                .controlSize(.small)
            }
            Text(ws.path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var plannedBranches: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(repos.filter { $0.role != .tickets }) { repo in
                HStack(spacing: 8) {
                    Text(repoLabel(repo.id)).font(.callout.weight(.semibold))
                    Text(plannedBranch).font(.callout.monospaced())
                    Text("· not started").font(.callout).foregroundStyle(.secondary)
                }
            }
            if repos.isEmpty {
                Text("No repositories are set up for this project yet.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var plannedBranch: String {
        let number: Int = ticket.ghNumber ?? ticket.id
        let slug = String(HatchStore.slug(ticket.title).prefix(32))
        return "ticket/\(number)-\(slug)"
    }

    private func openTerminal(_ path: String) {
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([URL(fileURLWithPath: path)], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Claims

    private var activeClaims: [Claim] { claims.filter { $0.state != "released" } }

    private var claimSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Files claimed")
                .font(.headline)
            if activeClaims.isEmpty {
                Text("No files claimed. An agent declares them when it plans the work.")
                    .foregroundStyle(.secondary)
            }
            ForEach(activeClaims) { claim in
                HStack(spacing: 8) {
                    Text(claim.pathGlob)
                        .font(.callout.monospaced())
                    Spacer()
                    PlainChip(text: claim.state)
                }
            }
        }
    }

    // MARK: Data

    private func load() {
        let store = state.store
        let id = ticket.id
        workspaces = (try? store.workspaces(ticketId: id)) ?? []
        repos = (try? store.repos(projectId: ticket.projectId)) ?? []
        claims = (try? store.claims(ticketId: id)) ?? []
        blockers = (try? store.openBlockers(ticketId: id)) ?? []
    }
}
