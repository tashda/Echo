import SwiftUI
import AppKit
import HatchCore

/// Agents and claims (decisions K1 to K5): who works on what, which files are claimed, what waits, and what it costs.
struct AgentsView: View {
    @EnvironmentObject var state: AppState
    /// Agents write through the CLI, so the screen reloads on a timer (K1).
    @State private var tick = 0

    struct RunRow: Identifiable {
        let id: Int
        let ticketId: Int?
        let agent: String
        let step: String?
        let startedAt: Date
        let tokensIn: Int
        let tokensOut: Int
    }

    // MARK: Data

    private var slots: (used: Int, max: Int) {
        let used = (try? state.store.activeAgentCount()) ?? 0
        let maxAgents = (try? state.store.maxAgents(projectId: state.projectFilterId)) ?? 3
        return (used, maxAgents)
    }

    private var working: [Ticket] {
        let all = (try? state.store.tickets(TicketFilter(projectId: state.projectFilterId, turn: .agent))) ?? []
        return all.filter { $0.takenBy != nil }
    }

    private var openRuns: [RunRow] {
        let sql = "SELECT id, ticket_id, agent, step, started_at, tokens_in, tokens_out FROM agent_run WHERE ended_at IS NULL ORDER BY started_at"
        let rows: [RunRow] = (try? state.store.db.query(sql) { r in
            RunRow(id: r.int("id") ?? 0, ticketId: r.int("ticket_id"), agent: r.string("agent") ?? "agent", step: r.string("step"),
                   startedAt: r.date("started_at") ?? Date(), tokensIn: r.int("tokens_in") ?? 0, tokensOut: r.int("tokens_out") ?? 0)
        }) ?? []
        return rows
    }

    private func run(for ticketId: Int) -> RunRow? { openRuns.last { $0.ticketId == ticketId } }

    private var allClaims: [Claim] {
        ((try? state.store.claims()) ?? []).filter { $0.state != "released" }
    }

    private func claimedFiles(_ ticketId: Int) -> [String] {
        allClaims.filter { $0.ticketId == ticketId && $0.state != "queued" }.map { $0.pathGlob }
    }

    private var queuedTicketIds: [Int] {
        var ids: [Int] = []
        for c in allClaims where c.state == "queued" && !ids.contains(c.ticketId) { ids.append(c.ticketId) }
        return ids
    }

    private func holders(of ticketId: Int) -> [Int] {
        let mine = allClaims.filter { $0.ticketId == ticketId && $0.state == "queued" }
        var out: [Int] = []
        for other in allClaims where other.ticketId != ticketId && (other.state == "held" || other.state == "stacked") && !out.contains(other.ticketId) {
            if mine.contains(where: { $0.repoId == other.repoId && Glob.mayOverlap($0.pathGlob, other.pathGlob) }) { out.append(other.ticketId) }
        }
        return out
    }

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private func tokenText(ticketId: Int?, since: Date?) -> String {
        let totals = (try? state.store.tokenTotals(ticketId: ticketId, since: since)) ?? (input: 0, output: 0)
        return hxTokens(totals.0 + totals.1)
    }

    private func ticket(_ id: Int) -> Ticket? {
        let t: Ticket? = try? state.store.ticket(id: id)
        return t
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HXHeader(title: "Agents", subtitle: summaryLine)
                runningSection
                waitingSection
                readySection
                costSection
            }
            .padding(20)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .autoReload(every: 5) { tick += 1 }
    }

    private var summaryLine: String {
        "\(tokenText(ticketId: nil, since: startOfToday)) tokens today."
    }

    // MARK: Running (K1)

    private var runningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Running").font(.headline)
            if working.isEmpty {
                HXCard { Text("No agent is working right now.").foregroundStyle(.secondary) }
            }
            ForEach(working) { t in runningCard(t) }
            slotRow
        }
    }

    /// The slots (K2): one dot per slot, filled while an agent uses it. The limit is set in Settings.
    private var slotRow: some View {
        let s = slots
        return HStack(spacing: 6) {
            ForEach(0..<max(s.max, 1), id: \.self) { index in
                Image(systemName: index < s.used ? "circle.fill" : "circle")
                    .imageScale(.small)
                    .foregroundStyle(index < s.used ? Theme.agent : Color.secondary)
            }
            Text("\(s.used) of \(s.max) slots in use. Change the limit in Settings.").font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func runningCard(_ t: Ticket) -> some View {
        let current = run(for: t.id)
        let files = claimedFiles(t.id)
        return HXCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text("Agent on \(t.displayNumber)").font(.headline)
                    Button { state.open(t) } label: {
                        Text(t.title).lineLimit(1)
                    }
                    .buttonStyle(.link)
                    HXChip(text: current?.step ?? t.status.displayName, turn: .agent)
                    Spacer()
                    runClock(current?.startedAt ?? t.updatedAt)
                }
                HStack(spacing: 14) {
                    Text("This run: \(hxTokens((current?.tokensIn ?? 0) + (current?.tokensOut ?? 0)))").font(.caption).foregroundStyle(.secondary)
                    Text("Ticket: \(tokenText(ticketId: t.id, since: nil))").font(.caption).foregroundStyle(.secondary)
                }
                Text(files.isEmpty ? "No files claimed yet" : "Files: " + files.map(shortName).joined(separator: ", "))
                    .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    Button(role: .destructive) { stop(t) } label: { Label("Stop", systemImage: "stop.fill") }
                        .tint(Theme.critical)
                    Button { takeOver(t) } label: { Label("Take over in Terminal", systemImage: "terminal") }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func runClock(_ start: Date) -> some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            Text(hxClock(context.date.timeIntervalSince(start))).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func shortName(_ path: String) -> String {
        let parts = path.split(separator: "/")
        return parts.last.map(String.init) ?? path
    }

    // MARK: Waiting (K3)

    @ViewBuilder private var waitingSection: some View {
        let ids = queuedTicketIds
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Waiting").font(.headline)
                ForEach(ids, id: \.self) { id in
                    if let t = ticket(id) { waitingCard(t) }
                }
            }
        }
    }

    private func waitingCard(_ t: Ticket) -> some View {
        let behind = holders(of: t.id)
        let names = behind.compactMap { ticket($0)?.displayNumber }.joined(separator: ", ")
        let firstName = behind.first.flatMap { ticket($0)?.displayNumber } ?? "the other ticket"
        return HXCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("\(t.displayNumber) \(t.title)").lineLimit(1)
                    HXStatusChip(status: t.status)
                }
                Text(names.isEmpty ? "Shares files with another ticket. Queued by default." : "Shares files with \(names). Queued after \(names) by default.")
                    .font(.callout).foregroundStyle(.secondary)
                Text("Recommended: keep it queued. It then builds on the finished work of \(firstName). Stack only if you want both on one branch.")
                    .font(.callout)
                if let base = behind.first {
                    Button {
                        state.perform("Stack") { try state.store.stack(ticketId: t.id, onto: base) }
                    } label: { Label("Stack on \(firstName)", systemImage: "square.3.layers.3d.down.left") }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
    }

    // MARK: Ready for an agent

    @ViewBuilder private var readySection: some View {
        let tasks = (try? state.store.agentWork(projectId: state.projectFilterId)) ?? []
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Ready for an agent").font(.headline)
                HXCard {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tasks, id: \.ticket.id) { task in
                            HStack {
                                Text("\(task.ticket.displayNumber) \(task.ticket.title)").lineLimit(1)
                                Spacer()
                                Text(task.kind.rawValue).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Cost (K5)

    /// Tokens per day for the last week, from running totals (tokenTotals only takes a start date).
    private var perDay: [(label: String, tokens: Int)] {
        let cal = Calendar.current
        var starts: [Date] = []
        for back in 0...7 { starts.append(cal.date(byAdding: .day, value: -back, to: startOfToday) ?? startOfToday) }
        let sums: [Int] = starts.map { start in
            let t = (try? state.store.tokenTotals(ticketId: nil, since: start)) ?? (input: 0, output: 0)
            return t.0 + t.1
        }
        var rows: [(label: String, tokens: Int)] = []
        for i in 0..<7 {
            let label = i == 0 ? "Today" : starts[i].formatted(.dateTime.weekday(.wide))
            rows.append((label: label, tokens: max(0, sums[i] - sums[i + 1])))
        }
        return rows
    }

    private var costSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tokens per day").font(.headline)
            HXCard {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(perDay.enumerated()), id: \.offset) { _, row in
                        LabeledContent(row.label) { Text(hxTokens(row.tokens)).monospacedDigit() }
                    }
                }
            }
        }
    }

    // MARK: Actions (I5)

    private func stop(_ t: Ticket) {
        let runs = openRuns.filter { $0.ticketId == t.id }
        state.perform("Stop agent") {
            for r in runs { try state.store.endRun(r.id, tokensIn: r.tokensIn, tokensOut: r.tokensOut, outcome: "stopped") }
            try state.store.release(t.id, reason: "stopped by the owner")
        }
    }

    private func takeOver(_ t: Ticket) {
        let spaces = (try? state.store.workspaces(ticketId: t.id)) ?? []
        guard let first = spaces.first else {
            state.errorMessage = "\(t.displayNumber) has no workspace yet."
            return
        }
        let folder = URL(fileURLWithPath: first.path, isDirectory: true)
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: config, completionHandler: nil)
    }
}
