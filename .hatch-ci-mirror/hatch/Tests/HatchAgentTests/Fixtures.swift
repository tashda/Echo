import XCTest
import Foundation
@testable import HatchAgent
@testable import HatchCore

/// A clock that moves one second per call, so events and notes never share a timestamp.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var t = 1_700_000_000.0
    func tick() -> Date { lock.lock(); defer { lock.unlock() }; t += 1; return Date(timeIntervalSince1970: t) }
}

enum Fixture {
    static let config = ProjectConfig(
        name: "Echo", ticketsRepo: "acme/tickets",
        repos: [
            RepoConfig(role: .app, remote: "acme/app", branch: "dev", buildCommand: "swift build", testPlans: ["UnitTests"]),
            RepoConfig(role: .specimens, remote: "acme/specimens", branch: "main"),
        ],
        areas: [AreaConfig(name: "Notifications", paths: ["Echo/Notifications/**", "Echo/Toast/*.swift"], specPrefix: "NOTIF", testPlans: ["NotificationTests"])],
        docs: ["docs/agents.md"])

    static func store() throws -> (HatchStore, Project) {
        let clock = TestClock()
        let store = try HatchStore.inMemory(now: { clock.tick() })
        let p = try store.upsertProject(key: "echo", name: "Echo", config: config)
        return (store, p)
    }

    /// Creates a ticket and walks it to `status` the way the app would.
    @discardableResult
    static func ticket(_ store: HatchStore, _ p: Project, type: TicketType = .proposal, title: String = "Toast spacing in dark mode",
                       body: String = "Toasts feel cramped in dark mode.", area: String? = "Notifications", status: Status = .draft) throws -> Ticket {
        let t = try store.createTicket(projectId: p.id, type: type, title: title, body: body, area: area, ghNumber: 151 + (try store.tickets().count))
        let path: [(Status, Actor)] = [(.checking, .owner), (.ready, .hatch)]
        for (s, a) in path {
            if status == .draft { break }
            try store.move(t.id, to: s, actor: a)
            if s == status { break }
        }
        return try store.ticket(id: t.id)!
    }

    /// A Proposal ticket that an agent has taken: Preparing and owned.
    static func preparing(_ store: HatchStore, _ p: Project, type: TicketType = .proposal) throws -> Ticket {
        let t = try ticket(store, p, type: type, status: .ready)
        try store.take(t.id, agent: "Agent on #151")
        return try store.ticket(id: t.id)!
    }

    static func manifest() -> ProposalManifest {
        var scenarios = StandardScenarios.all.map { ManifestScenario(id: $0.id, title: $0.title) }
        scenarios[1] = ManifestScenario(id: "hover", title: "Hover", applicable: false, notApplicableReason: "A toast has no pointer target.")
        return ProposalManifest(
            revision: 1, specs: ["NOTIF-1.2"], summary: "Tighter toast padding. Changes NOTIF-1.2.", asked: "Make toasts less cramped.",
            controls: [
                ManifestControl(id: "style", title: "Style", choices: [ManifestChoice(id: "quiet", name: "Quiet"), ManifestChoice(id: "bold", name: "Bold")],
                                defaultChoice: "quiet", question: "Look at the toast in dark mode, then say which reads better.", recommend: "quiet", why: "It matches the other banners and costs no new tokens."),
                ManifestControl(id: "speed", title: "Speed", choices: [ManifestChoice(id: "std", name: "Standard"), ManifestChoice(id: "slow", name: "Slow")], defaultChoice: "std"),
            ],
            specimens: [
                ManifestSpecimen(id: "today", title: "Echo today", isEchoToday: true, designWidth: 340, designHeight: 480),
                ManifestSpecimen(id: "a", title: "Tight", designWidth: 340, designHeight: 480),
                ManifestSpecimen(id: "b", title: "Airy", designWidth: 400, designHeight: 480),
            ],
            questions: [ManifestQuestion(id: "extra", title: "Empty state", question: "Is the empty state clear?",
                                         choices: [ManifestChoice(id: "yes", name: "Yes"), ManifestChoice(id: "no", name: "Needs changes")], recommended: "yes", why: "The hint names the next step.")],
            exhibitTopic: ManifestTopic(question: "Which proposal do you prefer?", recommended: "a", why: "It beats Echo today without adding height."),
            presets: [ManifestPreset(id: "rec", name: "My recommendation", values: ["style": "quiet"], isRecommended: true)],
            scenarios: scenarios)
    }
}

func codes(_ issues: [GateIssue]) -> [String] { issues.map(\.code) }
