import SwiftUI
import HatchCore

/// One group on the Desk: the tickets that wait for the owner in one status (decision C2).
struct DeskGroup: Identifiable {
    let status: Status
    let tickets: [Ticket]
    var id: String { status.rawValue }
}

/// What pressing A would do, shown in a confirmation sheet first (decision C5, H16). Never acts silently.
struct AcceptPlan: Identifiable {
    enum Kind {
        case proposal(choices: [String: String])
        case answers(pairs: [AnswerPair])
    }
    struct AnswerPair {
        let questionId: Int
        let text: String
    }
    let id: Int                 // ticket id
    let ticket: Ticket
    let lines: [String]
    let kind: Kind
}

struct DeskView: View {
    @EnvironmentObject var state: AppState
    @State private var groups: [DeskGroup] = []
    @State private var waiting: [Ticket] = []
    @State private var infos: [Int: ProposalInfo] = [:]
    @State private var questions: [Int: [Question]] = [:]
    @State private var selection: Int?
    @State private var showWaiting = false
    @State private var plan: AcceptPlan?
    @State private var notice: String?
    @State private var loaded = false
    @State private var projectNames: [Int: String] = [:]

    private var allQueued: [Ticket] { groups.flatMap { $0.tickets } }
    private var selectedTicket: Ticket? {
        guard let selection else { return nil }
        return (allQueued + waiting).first { $0.id == selection }
    }

    var body: some View {
        Group {
            if loaded && groups.isEmpty {
                allClear
            } else {
                splitContent
            }
        }
        .navigationTitle("Desk")
        .autoReload(every: 4) { load() }
        .sheet(item: $plan) { item in
            AcceptPlanSheet(plan: item) { confirmed in
                if confirmed { execute(item) }
                plan = nil
            }
        }
        .background(shortcutButtons)
    }

    // MARK: Layout

    private var splitContent: some View {
        HSplitView {
            listPane
                .frame(minWidth: 400)
            briefPane
                .frame(minWidth: 300, idealWidth: 360, maxWidth: 480)
        }
    }

    private var listPane: some View {
        List(selection: $selection) {
            ForEach(groups) { group in
                Section {
                    ForEach(group.tickets) { ticket in
                        DeskRow(ticket: ticket,
                                copy: copy(for: ticket),
                                recommendation: recommendationText(for: ticket),
                                showProject: state.selectedProjectKey == nil && projectNames.count > 1,
                                projectName: projectNames[ticket.projectId] ?? "")
                            .tag(ticket.id)
                            .contextMenu { rowMenu(ticket) }
                    }
                } header: {
                    groupHeader(title: group.status.displayName, count: group.tickets.count, color: Theme.you)
                }
            }
            if !waiting.isEmpty {
                Section {
                    if showWaiting {
                        ForEach(waiting) { ticket in
                            DeskWaitingRow(ticket: ticket)
                                .tag(ticket.id)
                        }
                    }
                } header: {
                    Button {
                        showWaiting.toggle()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showWaiting ? "chevron.down" : "chevron.right")
                                .font(.caption2)
                            groupHeader(title: "Waiting on agents", count: waiting.count, color: Theme.agent)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.inset)
        .onChange(of: allQueued.map { $0.id }) { _, _ in fixSelection() }
    }

    private var briefPane: some View {
        Group {
            if let ticket = selectedTicket {
                DeskBriefPane(ticket: ticket,
                              info: infos[ticket.id] ?? ProposalInfo(),
                              questions: questions[ticket.id] ?? [],
                              notice: notice,
                              onOpen: { open(ticket) },
                              onPark: { park(ticket) },
                              onAsk: { ask(ticket) },
                              onAccept: { prepareAccept(ticket) })
            } else {
                ContentUnavailableView("Select a ticket", systemImage: "tray", description: Text("Move with J and K. Return opens it."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func groupHeader(title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func rowMenu(_ ticket: Ticket) -> some View {
        Button("Open") { open(ticket) }
        Button("Park") { park(ticket) }
        Button("Ask") { ask(ticket) }
    }

    // MARK: Empty state (C6)

    private var allClear: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.finished)
            Text("All clear")
                .font(.title2.weight(.semibold))
            Text("Nothing waits for you.")
                .foregroundStyle(.secondary)
            agentSummary
                .frame(maxWidth: 460)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var agentSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            if waiting.isEmpty {
                Text("No agents are working right now.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Text("Agents are working on")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(waiting.prefix(6)) { ticket in
                    Button { open(ticket) } label: { DeskWaitingRow(ticket: ticket) }
                        .buttonStyle(.plain)
                }
                if waiting.count > 6 {
                    Text("and \(waiting.count - 6) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Keyboard (J, K, Return, P, A)

    private var shortcutButtons: some View {
        ZStack {
            Button("Next") { moveSelection(by: 1) }.keyboardShortcut("j", modifiers: [])
            Button("Previous") { moveSelection(by: -1) }.keyboardShortcut("k", modifiers: [])
            Button("Open") { if let t = selectedTicket { open(t) } }.keyboardShortcut(.return, modifiers: [])
            Button("Park") { if let t = selectedTicket { park(t) } }.keyboardShortcut("p", modifiers: [])
            Button("Accept") { if let t = selectedTicket { prepareAccept(t) } }.keyboardShortcut("a", modifiers: [])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }

    private func moveSelection(by delta: Int) {
        let ids: [Int] = allQueued.map { $0.id } + (showWaiting ? waiting.map { $0.id } : [])
        guard !ids.isEmpty else { return }
        guard let current = selection, let index = ids.firstIndex(of: current) else {
            selection = ids.first
            return
        }
        let next = min(max(index + delta, 0), ids.count - 1)
        selection = ids[next]
    }

    // MARK: Data

    private func load() {
        let pid = state.projectFilterId
        var names: [Int: String] = [:]
        for project in state.projects { names[project.id] = project.name }
        projectNames = names
        let queue = (try? state.store.deskQueue(projectId: pid)) ?? []
        var newGroups: [DeskGroup] = []
        for item in queue {
            let tickets: [Ticket] = item.tickets.filter { $0.type != .theme }
            if !tickets.isEmpty { newGroups.append(DeskGroup(status: item.status, tickets: tickets)) }
        }
        let agentTickets: [Ticket] = (try? state.store.tickets(TicketFilter(projectId: pid, turn: .agent))) ?? []
        let hatchTickets: [Ticket] = (try? state.store.tickets(TicketFilter(projectId: pid, turn: .hatch))) ?? []
        let newWaiting: [Ticket] = (agentTickets + hatchTickets).filter { $0.type != .theme && $0.status != .merged }
        var newInfos: [Int: ProposalInfo] = [:]
        var newQuestions: [Int: [Question]] = [:]
        for group in newGroups {
            for ticket in group.tickets {
                newInfos[ticket.id] = ProposalInfo.load(store: state.store, ticket: ticket)
                if ticket.status == .needsAnswers {
                    newQuestions[ticket.id] = (try? state.store.questions(ticketId: ticket.id, openOnly: true)) ?? []
                }
            }
        }
        groups = newGroups
        waiting = newWaiting
        infos = newInfos
        questions = newQuestions
        loaded = true
        fixSelection()
    }

    private func fixSelection() {
        let ids: [Int] = allQueued.map { $0.id } + waiting.map { $0.id }
        if let current = selection, ids.contains(current) { return }
        selection = allQueued.first?.id
    }

    private func copy(for ticket: Ticket) -> DeskCopy {
        DeskCopy.make(ticket: ticket, info: infos[ticket.id] ?? ProposalInfo(), openQuestions: questions[ticket.id]?.count ?? 0)
    }

    private func recommendationText(for ticket: Ticket) -> String? {
        guard ticket.status == .yourCall, let first = infos[ticket.id]?.recommendations.first else { return nil }
        return "Hatch recommends \(first.choiceName)"
    }

    // MARK: Actions

    private func open(_ ticket: Ticket) {
        state.open(ticket)
    }

    private func park(_ ticket: Ticket) {
        let id = ticket.id
        _ = state.perform("Could not park the ticket") { try state.store.move(id, to: .parked, actor: .owner, reason: "parked from the Desk") }
    }

    private func ask(_ ticket: Ticket) {
        state.selectedTicketId = ticket.id
        state.showAskPanel = true
    }

    private func prepareAccept(_ ticket: Ticket) {
        notice = nil
        if ticket.status == .yourCall && ticket.type == .proposal {
            let info = infos[ticket.id] ?? ProposalInfo()
            if info.recommendations.isEmpty {
                notice = "This Proposal has no recommendation. Open it to choose."
                return
            }
            var choices: [String: String] = [:]
            var lines: [String] = []
            for rec in info.recommendations {
                choices[rec.id] = rec.choiceId
                lines.append("\(rec.topicTitle): \(rec.choiceName)")
            }
            plan = AcceptPlan(id: ticket.id, ticket: ticket, lines: lines, kind: .proposal(choices: choices))
            return
        }
        if ticket.status == .needsAnswers {
            var pairs: [AcceptPlan.AnswerPair] = []
            var lines: [String] = []
            for question in questions[ticket.id] ?? [] {
                if let first = question.suggestions.first {
                    pairs.append(AcceptPlan.AnswerPair(questionId: question.id, text: first))
                    lines.append("\(question.text) \u{2192} \(first)")
                }
            }
            if pairs.isEmpty {
                notice = "These questions have no suggested answers. Open the ticket to answer them."
                return
            }
            plan = AcceptPlan(id: ticket.id, ticket: ticket, lines: lines, kind: .answers(pairs: pairs))
            return
        }
        notice = "There is nothing to accept from the list here. Press Return to open the ticket."
    }

    private func execute(_ plan: AcceptPlan) {
        switch plan.kind {
        case .proposal(let choices):
            let id = plan.id
            _ = state.perform("Could not accept the Proposal") { try state.store.acceptProposal(ticketId: id, choices: choices) }
        case .answers(let pairs):
            _ = state.perform("Could not save the answers") {
                for pair in pairs { _ = try state.store.answer(questionId: pair.questionId, text: pair.text) }
            }
        }
    }
}

struct DeskRow: View {
    let ticket: Ticket
    let copy: DeskCopy
    let recommendation: String?
    let showProject: Bool
    let projectName: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TypeBadge(type: ticket.type, showName: false)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(ticket.displayNumber)
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(ticket.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(copy.line)
                        .font(.caption)
                        .foregroundStyle(Theme.you)
                    if let recommendation {
                        Text("· \(recommendation)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 8)
            if showProject {
                PlainChip(text: projectName)
            }
            Text(Format.relative(ticket.updatedAt))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.vertical, 3)
    }
}

struct DeskWaitingRow: View {
    let ticket: Ticket

    var body: some View {
        HStack(spacing: 10) {
            TypeBadge(type: ticket.type, showName: false)
                .frame(width: 18)
            Text(ticket.displayNumber)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
            Text(ticket.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            if let who = ticket.takenBy {
                Text(who)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            StatusChip(status: ticket.status)
        }
        .padding(.vertical, 2)
    }
}

/// The confirmation shown before Hatch's recommendation is applied from the list.
struct AcceptPlanSheet: View {
    let plan: AcceptPlan
    let finish: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Accept the recommendation for \(plan.ticket.displayNumber)?")
                .font(.title3.weight(.semibold))
            Text(plan.ticket.title)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(plan.lines, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark").font(.caption).foregroundStyle(Theme.finished)
                        Text(line).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            Text(footnote)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Cancel") { finish(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Accept") { finish(true) }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var footnote: String {
        switch plan.kind {
        case .proposal:
            return "This picks these answers and moves the ticket to Accepted. An agent then builds it, which costs time and tokens. You have not opened the options yet; open the ticket first if you want to look."
        case .answers:
            return "These suggested answers are sent as your answers. Questions without a suggestion stay open."
        }
    }
}
