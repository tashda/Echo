import Foundation
import HatchCore

/// What `hatch take` prints: everything an agent needs for one ticket, in a fixed order, as compact deterministic text.
/// The rules for the task kind are written here once, so no agent has to remember a procedure (the owner's rule).
public enum BriefBuilder {
    public static let bodyLimit = 1500
    public static let relatedCap = 6
    public static let specCap = 8
    public static let notesCap = 8

    /// The task the ticket is in now. A taken ticket has already moved (Ready becomes Preparing or Building).
    public static func taskKind(for t: Ticket) -> AgentTaskKind? {
        switch t.status {
        case .checking: return .vet
        case .preparing: return .prepare
        case .building: return .build
        case .revising: return .revise
        case .fixing: return .fix
        default: return HatchStore.taskKind(for: t.status, type: t.type)
        }
    }

    public static func brief(store: HatchStore, ticketId: Int, agent: String, kind: AgentTaskKind? = nil) throws -> String {
        guard let t = try store.ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
        let kind = kind ?? taskKind(for: t)
        let project = try store.project(id: t.projectId)
        let config = project?.config
        var out: [String] = []

        out.append("# \(t.displayNumber) \(t.type.displayName) · \(t.status.displayName) · \(t.title)")
        out.append("You are \(agent). Task: \(kind.map(taskLine) ?? "none; this ticket is \(t.status.displayName) and waits for someone else.")")
        out.append("Project: \(project?.name ?? "?")" + (t.revision > 1 ? " · revision \(t.revision)" : ""))

        out.append("\n## Ticket")
        out.append(t.body.isEmpty ? "(no description)" : Text.clip(t.body, bodyLimit))
        if t.originalTitle != t.title || t.originalBody != t.body {
            out.append("\nOriginal text (the owner's own words, before the rewrite):")
            out.append(Text.indent("\(t.originalTitle ?? t.title)\n" + Text.clip(t.originalBody ?? "", 600)))
        }

        // The owner's answers to Iris's questions.
        let answered = try store.questions(ticketId: t.id).filter { !$0.isOpen }
        if !answered.isEmpty {
            out.append("\n## Owner's answers")
            for q in answered { out.append("- \(Text.oneLine(q.text, 160)) -> \(Text.oneLine(q.answer ?? "", 300))") }
        }
        let open = try store.questions(ticketId: t.id, openOnly: true)
        if !open.isEmpty {
            out.append("\n## Still unanswered")
            for q in open { out.append("- \(Text.oneLine(q.text, 160))") }
        }

        out += try proposalState(store, t, kind)
        out += try recentNotes(store, t)
        out += try linkLines(store, t)
        out += try relatedLines(store, t)
        out += try specLines(store, t)
        out += areaLines(config, t)
        out += try repoLines(store, t)
        if let config, !config.docs.isEmpty {
            out.append("\n## Docs to read")
            out.append(config.docs.map { "- \($0)" }.joined(separator: "\n"))
        }

        out.append("\n## Rules for this task")
        out.append(rules(kind: kind, ticket: t, config: config).enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n"))
        out.append("\n## Next")
        out.append(nextCommands(kind: kind, ticket: t).joined(separator: "\n"))
        return out.joined(separator: "\n") + "\n"
    }

    // MARK: Sections

    private static func taskLine(_ k: AgentTaskKind) -> String {
        switch k {
        case .vet: return "vet the ticket (questions, rewrite, type check)."
        case .prepare: return "prepare what the owner will judge."
        case .build: return "build the change."
        case .revise: return "revise the offer after the owner's feedback."
        case .fix: return "fix what the owner found while verifying."
        }
    }

    /// Picks, verdicts and pins: the owner's judgement of a Proposal. Only the tasks that continue from it need them.
    private static func proposalState(_ store: HatchStore, _ t: Ticket, _ kind: AgentTaskKind?) throws -> [String] {
        guard kind == .revise || kind == .build || kind == .fix else { return [] }
        var out: [String] = []
        let picks = try store.picks(ticketId: t.id)
        if !picks.isEmpty {
            out.append("\n## Owner's choices")
            for p in picks { out.append("- \(p.topic) = \(p.choice)" + (p.note.map { " (\(Text.oneLine($0, 200)))" } ?? "")) }
        }
        let verdicts = try store.verdicts(ticketId: t.id).filter { $0.verdict != "pick" }
        if !verdicts.isEmpty && kind == .revise {
            out.append("\n## Verdicts (maybe = keep refining, no = do not bring back)")
            for v in verdicts { out.append("- \(v.topic)/\(v.option): \(v.verdict)" + (v.note.map { " (\(Text.oneLine($0, 200)))" } ?? "")) }
        }
        let pins = try store.pins(ticketId: t.id)
        if !pins.isEmpty && kind == .revise {
            out.append("\n## Pinned notes")
            for p in pins.prefix(notesCap) {
                var where_: [String] = []
                if let o = p.option { where_.append(o) }
                if let s = p.scenario { where_.append(s) }
                if let a = p.appearance { where_.append(a) }
                if let c = p.corners { where_.append("corners \(c)") }
                out.append("- " + (where_.isEmpty ? "" : "[\(where_.joined(separator: ", "))] ") + Text.oneLine(p.text, 240))
            }
            if pins.count > notesCap { out.append("- ... and \(pins.count - notesCap) more (hatch show \(t.displayNumber))") }
        }
        if kind == .revise, let sendBack = try store.notes(ticketId: t.id).last(where: { $0.kind == .instruction }),
           let reason = sendBack.context?["reason"]?.stringValue {
            out.append("\nSend-back reason: \(reason)")
        }
        return out
    }

    /// Notes, asks and instructions the owner wrote since the agent last handed something back.
    private static func recentNotes(_ store: HatchStore, _ t: Ticket) throws -> [String] {
        let noteEvents = try store.events(ticketId: t.id, kinds: ["note", "offer", "ready"])
        func noteKind(_ e: Event) -> String? { e.kind == "note" ? e.payload["kind"]?.stringValue : nil }
        var cutoff = 0
        for e in noteEvents where e.kind == "offer" || e.kind == "ready" || noteKind(e) == "agent" { cutoff = max(cutoff, e.id) }
        var noteIDs = Set<Int>()
        for e in noteEvents where e.id > cutoff {
            if let k = noteKind(e), ["note", "ask", "instruction", "comment"].contains(k), let id = e.payload["note"]?.intValue { noteIDs.insert(id) }
        }
        let notes = try store.notes(ticketId: t.id).filter { noteIDs.contains($0.id) }
        guard !notes.isEmpty else { return [] }
        var out = ["\n## Since your last turn"]
        let shown = notes.suffix(notesCap)
        if notes.count > shown.count { out.append("(\(notes.count - shown.count) older not shown)") }
        for n in shown { out.append("- [\(n.kind.rawValue)] \(n.author): \(Text.oneLine(n.body, 400))") }
        return out
    }

    private static func describe(_ t: Ticket) -> String { "\(t.displayNumber) [\(t.type.rawValue), \(t.status.rawValue)] \(Text.oneLine(t.title, 90))" }

    private static func linkLines(_ store: HatchStore, _ t: Ticket) throws -> [String] {
        let links = try store.links(ticketId: t.id)
        var lines: [String] = []
        for (link, outgoing) in links.sorted(by: { ($0.link.kind.rawValue, $0.link.toId, $0.link.fromId) < ($1.link.kind.rawValue, $1.link.toId, $1.link.fromId) }) {
            guard let other = try store.ticket(id: outgoing ? link.toId : link.fromId) else { continue }
            let label = outgoing ? link.kind.rawValue : "is \(link.kind.rawValue) of"
            lines.append("- \(label) \(describe(other))")
        }
        return lines.isEmpty ? [] : ["\n## Links"] + lines
    }

    private static func relatedLines(_ store: HatchStore, _ t: Ticket) throws -> [String] {
        let linked = Set(try store.links(ticketId: t.id).map { $0.outgoing ? $0.link.toId : $0.link.fromId })
        let similar = try store.similarTickets(projectId: t.projectId, title: t.title, body: t.body, excluding: t.id, limit: relatedCap + linked.count + 2)
            .map(\.ticket).filter { !linked.contains($0.id) && $0.status != .dropped }.prefix(relatedCap)
        return similar.isEmpty ? [] : ["\n## Related tickets (search)"] + similar.map { "- " + describe($0) }
    }

    private static func specLines(_ store: HatchStore, _ t: Ticket) throws -> [String] {
        let hits = try store.searchSpec(projectId: t.projectId, query: t.title + " " + t.body, limit: specCap)
        return hits.isEmpty ? [] : ["\n## Spec items (search)"] + hits.map { "- \($0.code): \(Text.oneLine($0.text, 160))" }
    }

    private static func areaLines(_ config: ProjectConfig?, _ t: Ticket) -> [String] {
        guard let name = t.area else { return [] }
        guard let a = config?.areas.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return ["\n## Area\n\(name)"] }
        var out = ["\n## Area\n\(a.name)" + (a.specPrefix.map { " (Spec \($0)-*)" } ?? "")]
        out.append("Files: " + a.paths.joined(separator: ", "))
        if let plans = a.testPlans, !plans.isEmpty { out.append("Tests: " + plans.joined(separator: ", ")) }
        return out
    }

    private static func repoLines(_ store: HatchStore, _ t: Ticket) throws -> [String] {
        let repos = try store.repos(projectId: t.projectId)
        guard !repos.isEmpty else { return [] }
        let workspaces = try store.workspaces(ticketId: t.id)
        var out = ["\n## Repos"]
        for r in repos {
            var line = "- \(r.role.rawValue): \(r.remote) (base \(r.defaultBranch))"
            if let b = r.buildCommand { line += " · build: \(b)" }
            if !r.testPlans.isEmpty { line += " · tests: \(r.testPlans.joined(separator: ", "))" }
            if let w = workspaces.first(where: { $0.repoId == r.id }) { line += "\n    workspace: \(w.path) on branch \(w.branch)" }
            out.append(line)
        }
        return out
    }

    // MARK: Rules

    static func branchName(_ t: Ticket) -> String { "ticket/\(t.ghNumber ?? t.id)-\(HatchStore.slug(t.title).prefix(40))" }

    /// The rules for each task, copied from the design (decisions G, H, I, K and S). Short on purpose.
    public static func rules(kind: AgentTaskKind?, ticket t: Ticket, config: ProjectConfig?) -> [String] {
        let common = [
            "Hatch changes the status, never you. Do not edit labels, state or the database; use the commands under Next.",
            "If something blocks you and only the owner can answer, run `hatch ask` with your recommendation. Do not guess.",
        ]
        switch kind {
        case nil:
            return ["Nothing to do on this ticket right now."]
        case .vet:
            return ["Compare the ticket with the other tickets and the Spec. Iris does this through `hatch`; you only read the result.",
                    "The owner decides every suggestion (rewrite, type change, duplicate)."]
        case .prepare:
            switch t.type {
            case .sketch:
                return [
                    "Draw 2 to 4 HTML variants of the layout or flow. They are concepts, not Swift; do not write Swift.",
                    "Each variant is one self-contained HTML file with its own id and title. Write a manifest JSON: {\"summary\": \"...\", \"variants\": [{\"id\", \"title\", \"html\"}]}.",
                    "Say in the summary what differs between the variants and which one you would pick, with the reason.",
                ] + common + ["Hand it in with `hatch offer`. Never move the status yourself."]
            case .question:
                return [
                    "Answer in words. Look up the Spec first and name the Spec IDs the answer touches.",
                    "Give one recommendation and the reason. If it needs a decision between options, say which one you would ship.",
                ] + common + ["Hand the answer in with `hatch offer`. Never move the status yourself."]
            default:
                return [
                    "Look up the area in the Spec and note the Spec IDs you change; put them in the manifest `specs` and in the summary.",
                    "The first specimen is Echo today (`isEchoToday: true`), drawn from what Echo really does (read the real view, not memory).",
                    "Then 2 to 4 proposals as Swift specimens in the specimens repo, same sample data in all, each with `designWidth` and `designHeight` (340 to 700 wide, up to about 620 tall). No title inside a specimen.",
                    "Cover the standard scenarios (Rest, Hover, Pressed, Focus, Disabled, Empty, Error, Long text, Many items, Loading), or mark one `applicable: false` with a `notApplicableReason`.",
                    "Every control with a `question`, every question and the specimen topic carries ONE recommendation and its reason: the option you would ship, not a safe middle. The reason says what the others cost.",
                    "Write a question as what to do, then what to decide. Choice names are short and stable.",
                    "Mark exactly one preset `isRecommended: true` so the owner can try your whole recommendation in one click.",
                ] + common + [
                    "Hand it in with `hatch offer`. Hatch runs the quality gate and builds the Stage; errors come back to you. Never move the status yourself.",
                ]
            }
        case .revise:
            return [
                "Keep every earlier option, control, question and choice. Only add. Never rename a choice the owner already answered.",
                "Mark everything new with `addedIn: \(t.revision + 1)` and set `revision` to \(t.revision + 1).",
                "Follow the send-back reason: needs more options = add options; change an option = edit that one; different direction = a new angle, still keeping the old options.",
                "A Maybe verdict means keep refining that option. A No means do not bring it back.",
            ] + common + ["Hand it in with `hatch offer`. Never move the status yourself."]
        case .build:
            let limit = config?.planApprovalFileThreshold ?? 8
            return [
                "Work only in your own worktree on branch `\(branchName(t))`. Never touch the main checkout. Push only that branch.",
                "Declare the files you will touch with `hatch plan` before you edit. If another ticket holds them you are queued.",
                "A Bug, or a change over \(limit) files, waits for the owner to approve the plan; Hatch tells you.",
                t.type == .proposal ? "Build the owner's accepted choices exactly (see Owner's choices). Update the Spec text for the Spec IDs you change." : "Make the smallest change that fixes it, and update the Spec text if behaviour changes.",
                "Run only the tests mapped to this area, in your worktree. Do not run the full suite or a full build; CI does that.",
                "When done run `hatch ready`. Hatch runs the build, tests and match check and moves the ticket to To verify.",
            ] + common
        case .fix:
            return [
                "Read the owner's notes under Since your last turn and fix exactly that, on the same branch `\(branchName(t))`.",
                "Run only the tests mapped to this area. No full suite.",
                "When done run `hatch ready`. Hatch moves the ticket back to To verify.",
            ] + common
        }
    }

    static func nextCommands(kind: AgentTaskKind?, ticket t: Ticket) -> [String] {
        let n = t.displayNumber
        switch kind {
        case nil, .vet?: return ["(nothing for you to run)"]
        case .prepare?, .revise?:
            let file: String
            switch t.type { case .sketch: file = "sketch.json"; case .question: file = "--answer \"...\""; default: file = "manifest.json" }
            return ["hatch offer \(n) \(file)     # when ready; Hatch checks it and moves the ticket",
                    "hatch ask \(n) \"...\"     # only if you are blocked",
                    "hatch note \(n) \"...\"    # context for the owner"]
        case .build?, .fix?:
            return (kind == .build ? ["hatch plan \(n) --files <paths>   # before you edit"] : [])
                + ["hatch ready \(n)     # when the work is done",
                   "hatch ask \(n) \"...\"     # only if you are blocked",
                   "hatch note \(n) \"...\"    # progress for the owner"]
        }
    }
}
