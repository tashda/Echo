import Foundation
import HatchCore

public enum OfferResult: Equatable, Sendable {
    /// The gate passed: the ticket is now Your call and the agent is released. Warnings are advice, not blockers.
    case offered(ticket: Ticket, revision: Int, warnings: [GateIssue])
    /// The gate found errors. Nothing changed; the agent fixes them and offers again.
    case rejected([GateIssue])

    public var issues: [GateIssue] {
        switch self { case .offered(_, _, let w): return w; case .rejected(let i): return i }
    }
    public var isOffered: Bool { if case .offered = self { return true }; return false }
}

/// `hatch offer`: the one door from Preparing or Revising to Your call. Hatch moves the status (never the agent) and only
/// after the quality gate passes (decisions H19 and S6).
public struct OfferService {
    public let store: HatchStore
    public var agent: String
    /// Extra checks that need more than the manifest, such as building the Stage and running it headless (S6).
    /// They run after the manifest rules pass and may add issues; any error rejects the offer.
    public var stageCheck: (@Sendable (Ticket, ProposalManifest) throws -> [GateIssue])?

    public init(store: HatchStore, agent: String = "agent", stageCheck: (@Sendable (Ticket, ProposalManifest) throws -> [GateIssue])? = nil) {
        self.store = store; self.agent = agent; self.stageCheck = stageCheck
    }

    /// Parses the JSON an agent wrote, then offers it. Bad JSON is a rejection with a clear message, not a crash.
    public func offer(ticketId: Int, json: String) throws -> OfferResult {
        do { return try offer(ticketId: ticketId, manifest: ProposalManifest.parse(json: json)) }
        catch let e as ManifestError {
            return .rejected([.error("manifest.invalid", e.description, "Fix the JSON and offer again. Expected keys: controls, specimens, questions, exhibitTopic, presets, scenarios, conformance, revision, specs, summary, asked.")])
        }
    }

    public func offer(ticketId: Int, manifest: ProposalManifest) throws -> OfferResult {
        let t = try offerable(ticketId, types: [.proposal])
        let revising = t.status == .revising
        var issues: [GateIssue] = []

        let expected = revising ? t.revision + 1 : 1
        if manifest.revision != expected {
            issues.append(.error("revision.expected", "The manifest says revision \(manifest.revision) but this ticket is at revision \(expected).",
                                 "Set revision to \(expected)."))
        }
        var previous: ProposalManifest?
        if revising, let json = try store.proposalManifest(ticketId: ticketId) { previous = try? ProposalManifest.parse(json: json) }
        let picks = Dictionary(try store.picks(ticketId: ticketId).map { ($0.topic, $0.choice) }, uniquingKeysWith: { _, b in b })
        issues += ProposalValidator.validate(manifest, previous: previous, picks: picks)
        if !issues.hasErrors, let stageCheck { issues += try stageCheck(t, manifest) }
        if issues.hasErrors { return try reject(t, issues) }

        let json = try manifest.jsonString()
        let moved = try store.db.transaction { () -> Ticket in
            if revising { try store.recordRevision(ticketId: ticketId, summary: manifest.summary, added: Self.added(in: manifest, since: previous)) }
            try store.saveProposal(ticketId: ticketId, manifestJSON: json)
            return try finish(t, summary: manifest.summary, revision: manifest.revision, warnings: issues.count)
        }
        return .offered(ticket: moved, revision: manifest.revision, warnings: issues)
    }

    /// A Sketch: 2 to 4 HTML variants. `baseDirectory` is where the variant files sit, checked when given.
    public func offer(ticketId: Int, sketch: SketchManifest, baseDirectory: URL? = nil) throws -> OfferResult {
        let t = try offerable(ticketId, types: [.sketch])
        let revising = t.status == .revising
        var issues = sketch.validate(baseDirectory: baseDirectory)
        var previous: SketchManifest?
        if revising, let json = try store.proposalManifest(ticketId: ticketId) { previous = try? SketchManifest.parse(json: json) }
        if let previous {
            for v in previous.variants where !sketch.variants.contains(where: { $0.id == v.id }) {
                issues.append(.error("sketch.variant-removed", "Variant '\(v.id)' from the earlier version is gone.", "Keep earlier variants and add new ones; the owner's comments refer to them."))
            }
        }
        if issues.hasErrors { return try reject(t, issues) }
        let json = String(decoding: try JSONEncoder().encode(sketch), as: UTF8.self)
        let moved = try store.db.transaction { () -> Ticket in
            if revising {
                let old = Set(previous?.variants.map(\.id) ?? [])
                try store.recordRevision(ticketId: ticketId, summary: sketch.summary, added: sketch.variants.filter { !old.contains($0.id) }.map { "New variant: \($0.id) · \($0.title)" })
            }
            try store.saveProposal(ticketId: ticketId, manifestJSON: json)
            return try finish(t, summary: sketch.summary, revision: revising ? t.revision + 1 : 1, warnings: 0)
        }
        return .offered(ticket: moved, revision: revising ? t.revision + 1 : 1, warnings: issues)
    }

    /// A Question: the answer is a note in the thread, and the ticket goes to the owner.
    public func offerAnswer(ticketId: Int, answer: String) throws -> OfferResult {
        let t = try offerable(ticketId, types: [.question])
        guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return try reject(t, [.error("answer.empty", "The answer is empty.", "Write the answer to the owner's question, with your recommendation and the reason.")])
        }
        let moved = try store.db.transaction { try finish(t, summary: answer, revision: 1, warnings: 0) }
        return .offered(ticket: moved, revision: 1, warnings: [])
    }

    // MARK: Pieces

    private func offerable(_ id: Int, types: Set<TicketType>) throws -> Ticket {
        guard let t = try store.ticket(id: id) else { throw StoreError.notFound("ticket \(id)") }
        guard types.contains(t.type) else {
            throw StoreError.invalid("\(t.displayNumber) is a \(t.type.displayName); this kind of offer is for \(types.map(\.displayName).sorted().joined(separator: " or ")).")
        }
        guard t.status == .preparing || t.status == .revising else {
            throw StoreError.invalid("\(t.displayNumber) is \(t.status.displayName); you can only offer while it is Preparing or Revising. Use `hatch take` first.")
        }
        return t
    }

    private func reject(_ t: Ticket, _ issues: [GateIssue]) throws -> OfferResult {
        try store.record(t.id, actor: "hatch", kind: "offer-rejected", payload: ["codes": .array(issues.errors.map { .string($0.code) })])
        return .rejected(issues)
    }

    /// Posts the summary, records the offer, and lets Hatch (not the agent) move the ticket to Your call and release it.
    private func finish(_ t: Ticket, summary: String, revision: Int, warnings: Int) throws -> Ticket {
        if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try store.addNote(t.id, kind: .agent, author: agent, body: summary)
        }
        try store.record(t.id, actor: agent, kind: "offer", payload: ["revision": .int(revision), "warnings": .int(warnings)])
        return try store.move(t.id, to: .yourCall, actor: .hatch, reason: "offered")
    }

    /// One line per new item, the way Echo Labs' revise script wrote them, for the owner's "New since your last review" card.
    static func added(in m: ProposalManifest, since old: ProposalManifest?) -> [String] {
        var out: [String] = []
        let oldControls = Set(old?.controls.map(\.id) ?? []), oldSpecimens = Set(old?.specimens.map(\.id) ?? []), oldQuestions = Set(old?.questions.map(\.id) ?? [])
        for c in m.controls {
            if !oldControls.contains(c.id) { out.append("New control: \(c.id) · \(c.title)"); continue }
            let oldChoices = Set(old?.controls.first { $0.id == c.id }?.choices.map(\.id) ?? [])
            for ch in c.choices where !oldChoices.contains(ch.id) { out.append("New option: \(c.id) · \(ch.name)") }
        }
        for s in m.specimens where !oldSpecimens.contains(s.id) { out.append("New specimen: \(s.id) · \(s.title)") }
        for q in m.questions {
            if !oldQuestions.contains(q.id) { out.append("New question: \(q.id) · \(q.title)"); continue }
            let oldChoices = Set(old?.questions.first { $0.id == q.id }?.choices.map(\.id) ?? [])
            for ch in q.choices where !oldChoices.contains(ch.id) { out.append("New option: \(q.id) · \(ch.name)") }
        }
        return out
    }
}
