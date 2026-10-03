import SwiftUI
import HatchCore

enum TicketTab: String, CaseIterable, Identifiable {
    case overview, options, thread, work, history
    var id: String { rawValue }
}

/// What the banner says and which buttons it offers for a ticket in its current status (decision F2).
enum BannerAction {
    case openStage
    case tab(TicketTab)
    case submit
    case previews
    case closeAsAnswered
    case resume
    case reopen
}

struct BannerSpec {
    var message: String
    var primaryTitle: String?
    var primary: BannerAction?
    var secondaryTitle: String?
    var secondary: BannerAction?
}

/// The page for one ticket, whatever its type: header, banner with the main action, then tabs (decisions F1 to F5).
struct TicketDetailView: View {
    let ticketId: Int
    @EnvironmentObject var state: AppState
    @State private var ticket: Ticket?
    @State private var tab: TicketTab = .overview
    @State private var openQuestions = 0
    @State private var threadCount = 0
    @State private var info = ProposalInfo()
    @State private var confirmDrop = false
    @State private var threadKind: NoteKind = .note

    var body: some View {
        Group {
            if let ticket {
                page(ticket)
            } else {
                ContentUnavailableView("Ticket not found", systemImage: "questionmark.folder",
                                       description: Text("It may have been removed."))
            }
        }
        .navigationTitle(ticket?.displayNumber ?? "Ticket")
        .autoReload(every: 3) { load() }
        .onChange(of: tab) { _, newTab in
            if newTab != .thread { threadKind = .note }
        }
        .onChange(of: ticketId) { _, _ in
            tab = .overview
            load()
        }
        .confirmationDialog("Drop this ticket?", isPresented: $confirmDrop) {
            Button("Drop", role: .destructive) { move(to: .dropped) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A dropped ticket is closed on GitHub as not planned. You can reopen it later.")
        }
    }

    // MARK: Page

    private func page(_ t: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                header(t)
                banner(t)
                tabBar(t)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)
            Divider()
            tabContent(t)
        }
    }

    private func header(_ t: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                state.route = .desk
            } label: {
                Label("Desk", systemImage: "chevron.left")
                    .font(.callout)
            }
            .buttonStyle(.link)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(t.displayNumber)
                    .font(.title2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(t.title)
                    .font(.title2.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                headerButtons(t)
            }
            HStack(spacing: 8) {
                StatusChip(status: t.status)
                TypeBadge(type: t.type)
                if let name = state.project(id: t.projectId)?.name { PlainChip(text: name) }
                if let area = t.area, !area.isEmpty { PlainChip(text: area) }
            }
        }
    }

    @ViewBuilder private func headerButtons(_ t: Ticket) -> some View {
        HStack(spacing: 8) {
            // Parked and Dropped already offer Resume and Reopen as the banner's main action (F2), so the header does not repeat them.
            if t.status == .blocked {
                Button { resume() } label: { Label("Resume", systemImage: "play") }.buttonStyle(.glass)
            } else if canMove(t, to: .parked) {
                Button { move(to: .parked) } label: { Label("Park", systemImage: "pause") }.buttonStyle(.glass)
            }
            if t.status == .done {
                Button { move(to: .draft) } label: { Label("Reopen", systemImage: "arrow.uturn.backward") }.buttonStyle(.glass)
            }
            if canMove(t, to: .dropped) {
                // Rare and hard to undo: behind More, then a confirmation (LK11).
                HXMenuButton(title: "More", symbol: "ellipsis") {
                    Button("Drop", role: .destructive) { confirmDrop = true }
                }
            }
        }
        .controlSize(.large)
    }

    private func canMove(_ t: Ticket, to target: Status) -> Bool {
        Workflow.isAllowed(type: t.type, from: t.status, to: target, actor: .owner)
    }

    // MARK: Banner

    private func banner(_ t: Ticket) -> some View {
        let spec = bannerSpec(t)
        return TurnBanner(turn: t.turn,
                          message: spec.message,
                          actionTitle: spec.primaryTitle,
                          action: handler(spec.primary, t),
                          secondaryTitle: spec.secondaryTitle,
                          secondaryAction: handler(spec.secondary, t))
    }

    private func handler(_ action: BannerAction?, _ t: Ticket) -> (() -> Void)? {
        guard let action else { return nil }
        return { perform(action, t) }
    }

    private func bannerSpec(_ t: Ticket) -> BannerSpec {
        switch t.status {
        case .draft:
            return BannerSpec(message: "This is a draft. Submit it and Iris checks it before any work starts.",
                              primaryTitle: "Submit for check", primary: .submit)
        case .checking:
            return BannerSpec(message: "Iris is checking this ticket against other tickets and the Spec.")
        case .needsAnswers:
            let n = max(openQuestions, 0)
            let text: String = n > 0 ? "Answer \(Format.count(n, "question")) so work can start." : "Look at Iris's suggestion below so work can start."
            return BannerSpec(message: text, primaryTitle: "Answer below", primary: .tab(.overview))
        case .ready:
            return BannerSpec(message: "Ready. Hatch hands it to an agent as soon as a slot is free.")
        case .preparing:
            let what: String = t.type == .question ? "an answer" : (t.type == .sketch ? "variants" : "options")
            return BannerSpec(message: "An agent is preparing \(what). You will see it here when it is ready.")
        case .yourCall:
            return yourCallSpec(t)
        case .revising:
            return BannerSpec(message: "An agent is revising. Revision \(t.revision + 1) will appear here.")
        case .accepted:
            return BannerSpec(message: "Accepted. Hatch starts the build when a slot is free.")
        case .building:
            return BannerSpec(message: "An agent is building this in its own workspace.",
                              primaryTitle: "See progress", primary: .tab(.work))
        case .toVerify:
            return BannerSpec(message: "Verify the change in a Preview and say whether it looks right.",
                              primaryTitle: "Open in Previews", primary: .previews)
        case .fixing:
            return BannerSpec(message: "An agent is fixing what you reported.",
                              primaryTitle: "See progress", primary: .tab(.work))
        case .merged:
            return BannerSpec(message: "Merged into the integration branch. Hatch waits for its checks.")
        case .done:
            return BannerSpec(message: "Done.", primaryTitle: nil, primary: nil)
        case .blocked:
            return BannerSpec(message: "Blocked. It waits for another ticket or for files another ticket is changing.",
                              primaryTitle: "See why", primary: .tab(.work))
        case .parked:
            return BannerSpec(message: "Parked. Nothing happens until you resume it.", primaryTitle: "Resume", primary: .resume)
        case .dropped:
            return BannerSpec(message: "Dropped. It is closed on GitHub as not planned.", primaryTitle: "Reopen", primary: .reopen)
        }
    }

    private func yourCallSpec(_ t: Ticket) -> BannerSpec {
        switch t.type {
        case .proposal:
            let n = max(info.optionCount, 1)
            return BannerSpec(message: "Judge \(Format.count(n, "option")) against Echo today. Revision \(t.revision).",
                              primaryTitle: "Open the Proposal", primary: .openStage)
        case .sketch:
            return BannerSpec(message: "Choose a direction from the variants, or ask for more.",
                              primaryTitle: "Choose direction", primary: .tab(.options))
        default:
            return BannerSpec(message: "The agent replied. Answer in the thread, or close the question.",
                              primaryTitle: "Reply", primary: .tab(.thread),
                              secondaryTitle: "Close as answered", secondary: .closeAsAnswered)
        }
    }

    private func perform(_ action: BannerAction, _ t: Ticket) {
        switch action {
        case .openStage:
            StageLauncher.shared.open(ticket: t, state: state)
        case .tab(let target):
            tab = target
        case .submit:
            let id = t.id
            let moved: Ticket? = state.perform("Could not submit the ticket") { try state.store.move(id, to: .checking, actor: .owner, reason: "submitted for check") }
            if moved != nil { VettingBridge.start(ticketId: id, state: state) }
        case .previews:
            state.route = .previews
        case .closeAsAnswered:
            move(to: .done)
        case .resume:
            resume()
        case .reopen:
            move(to: .draft)
        }
    }

    private func move(to target: Status) {
        let id = ticketId
        _ = state.perform("Could not change the status") { try state.store.move(id, to: target, actor: .owner) }
    }

    private func resume() {
        let id = ticketId
        _ = state.perform("Could not resume the ticket") { try state.store.resume(id, actor: .owner) }
    }

    // MARK: Tabs

    private func visibleTabs(_ t: Ticket) -> [TicketTab] {
        var tabs: [TicketTab] = [.overview]
        if t.type == .sketch || t.type == .proposal { tabs.append(.options) }
        tabs.append(.thread)
        if t.type != .theme { tabs.append(.work) }
        tabs.append(.history)
        return tabs
    }

    private func tabTitle(_ tab: TicketTab, _ t: Ticket) -> String {
        switch tab {
        case .overview: return "Overview"
        case .options: return t.type == .sketch ? "Variants" : "Options"
        case .thread: return threadCount > 0 ? "Thread (\(threadCount))" : "Thread"
        case .work: return "Work"
        case .history: return "History"
        }
    }

    private func tabBar(_ t: Ticket) -> some View {
        HXDock(items: visibleTabs(t).map { HXDock.Item(id: $0, title: tabTitle($0, t)) }, selection: $tab)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private func tabContent(_ t: Ticket) -> some View {
        let current: TicketTab = visibleTabs(t).contains(tab) ? tab : .overview
        switch current {
        case .overview: TicketOverviewTab(ticket: t)
        case .options: TicketOptionsTab(ticket: t, info: info)
        case .thread: TicketThreadTab(ticket: t, startKind: threadKind)
        case .work:
            TicketWorkTab(ticket: t, onInstruction: {
                threadKind = .instruction
                tab = .thread
            })
        case .history: TicketHistoryTab(ticket: t)
        }
    }

    // MARK: Data

    private func load() {
        guard let t = try? state.store.ticket(id: ticketId) else {
            ticket = nil
            return
        }
        if ticket != t { ticket = t }
        let openCount = ((try? state.store.questions(ticketId: ticketId, openOnly: true)) ?? []).count
        if openCount != openQuestions { openQuestions = openCount }
        let notes = ((try? state.store.notes(ticketId: ticketId)) ?? []).count
        let questions = ((try? state.store.questions(ticketId: ticketId)) ?? []).count
        if notes + questions != threadCount { threadCount = notes + questions }
        info = ProposalInfo.load(store: state.store, ticket: t)
        if state.selectedTicketId != ticketId { state.selectedTicketId = ticketId }
    }
}
