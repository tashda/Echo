import Foundation
import HatchCore

typealias Handler = (Context) throws -> Void

/// Commands that only need the core store. Agent-facing commands (take, offer, ready, ...) live in AgentCommands.swift.
enum CoreCommands {
    static let all: [String: Handler] = [
        "init": initProject,
        "status": status,
        "ticket": ticket,
        "next": next,
        "ask": ask,
        "plan": plan,
        "note": note,
        "search": search,
        "admin": admin,
    ]

    // hatch init [--config .hatch/project.json] [--key echo --name Echo --tickets owner/repo]
    static func initProject(_ c: Context) throws {
        if let path = c.args.option("config") {
            let config = try ProjectConfig.load(from: URL(fileURLWithPath: path))
            let key = c.args.option("key") ?? config.name.lowercased().filter { $0.isLetter || $0.isNumber }
            let p = try c.store.upsertProject(key: key, name: config.name, config: config)
            c.out.emit(["project": .string(p.key), "repos": .int(config.repos.count)], text: "Project \(p.key) registered with \(config.repos.count) repositories.")
        } else if let key = c.args.option("key"), let name = c.args.option("name") {
            let tickets = c.args.option("tickets") ?? "tashda/hatch-tickets"
            let p = try c.store.upsertProject(key: key, name: name, config: ProjectConfig(name: name, ticketsRepo: tickets))
            c.out.emit(["project": .string(p.key)], text: "Project \(p.key) registered.")
        } else {
            throw CLIError("Usage: hatch init --config <.hatch/project.json> [--key echo]   or   hatch init --key echo --name Echo [--tickets owner/repo]")
        }
    }

    // hatch status
    static func status(_ c: Context) throws {
        let pid = try? c.project().id
        let counts = try c.store.countByTurn(projectId: pid)
        let queue = try c.store.deskQueue(projectId: pid)
        let sync = try c.store.syncCounts()
        let json: JSONValue = [
            "waitingForYou": .int(counts[.you] ?? 0), "withAgents": .int(counts[.agent] ?? 0), "withHatch": .int(counts[.hatch] ?? 0),
            "syncPending": .int(sync.pending), "syncFailed": .int(sync.failed),
            "agentsRunning": .int(try c.store.activeAgentCount()),
        ]
        var text = "Waiting for you: \(counts[.you] ?? 0)   With agents: \(counts[.agent] ?? 0)   With Hatch: \(counts[.hatch] ?? 0)\n"
        text += "Sync: \(sync.pending) pending, \(sync.failed) failed   Agents running: \(try c.store.activeAgentCount())"
        for group in queue { text += "\n\n\(group.status.displayName)\n" + group.tickets.map { "  " + $0.oneLine }.joined(separator: "\n") }
        c.out.emit(json, text: text)
    }

    // hatch ticket new|list|show|link
    static func ticket(_ c: Context) throws {
        switch c.args.pos(1) {
        case "new": try ticketNew(c)
        case "list": try ticketList(c)
        case "show": try ticketShow(c)
        case "link": try ticketLink(c)
        default: throw CLIError("Usage: hatch ticket new|list|show|link ...")
        }
    }

    static func ticketNew(_ c: Context) throws {
        let p = try c.project()
        guard let typeName = c.args.option("type"), let type = TicketType(rawValue: typeName) else {
            throw CLIError("--type must be one of: \(TicketType.allCases.map(\.rawValue).joined(separator: ", "))")
        }
        guard let title = c.args.option("title") else { throw CLIError("--title is required.") }
        let parent = try c.args.option("parent").map { try c.store.resolve($0).id }
        var t = try c.store.createTicket(projectId: p.id, type: type, title: title, body: c.args.option("body") ?? "", area: c.args.option("area"), parentId: parent)
        if c.args.flag("submit") { t = try c.store.move(t.id, to: .checking, actor: .owner) }
        c.out.emit(t.asJSON, text: "Created \(t.oneLine)")
    }

    static func ticketList(_ c: Context) throws {
        var filter = TicketFilter(projectId: try? c.project().id)
        if let s = c.args.option("status") { filter.statuses = s.split(separator: ",").compactMap { Status(rawValue: String($0)) } }
        if let t = c.args.option("type") { filter.types = t.split(separator: ",").compactMap { TicketType(rawValue: String($0)) } }
        if let t = c.args.option("turn") { filter.turn = Turn(rawValue: t) }
        if let q = c.args.option("text") { filter.text = q }
        if c.args.flag("all") { filter.projectId = nil }
        let tickets = try c.store.tickets(filter)
        c.out.emit(.array(tickets.map(\.asJSON)), text: tickets.isEmpty ? "No tickets." : tickets.map(\.oneLine).joined(separator: "\n"))
    }

    static func ticketShow(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(2))
        let notes = try c.store.notes(ticketId: t.id), questions = try c.store.questions(ticketId: t.id), links = try c.store.links(ticketId: t.id)
        var text = "\(t.oneLine)\nTurn: \(Theme.title(t.turn))   Revision: \(t.revision)   Taken by: \(t.takenBy ?? "nobody")\n\n\(t.body)"
        if !questions.isEmpty { text += "\n\nQuestions:\n" + questions.map { "  [\($0.isOpen ? "open" : "answered")] \($0.text)" + ($0.answer.map { " -> \($0)" } ?? "") }.joined(separator: "\n") }
        if !links.isEmpty { text += "\n\nLinks:\n" + links.map { "  \($0.link.kind.rawValue) \($0.outgoing ? "->" : "<-") \((try? c.store.ticket(id: $0.outgoing ? $0.link.toId : $0.link.fromId))??.displayNumber ?? "?")" }.joined(separator: "\n") }
        if !notes.isEmpty { text += "\n\nThread:\n" + notes.map { "  \($0.author) (\($0.kind.rawValue)): \($0.body)" }.joined(separator: "\n") }
        var json = t.asJSON.objectValue ?? [:]
        json["body"] = .string(t.body)
        json["notes"] = .array(notes.map { ["kind": .string($0.kind.rawValue), "author": .string($0.author), "body": .string($0.body)] })
        json["questions"] = .array(questions.map { ["id": .int($0.id), "text": .string($0.text), "answer": $0.answer.map { .string($0) } ?? .null] })
        c.out.emit(.object(json), text: text)
    }

    static func ticketLink(_ c: Context) throws {
        let a = try c.ticket(c.args.pos(2)), b = try c.ticket(c.args.pos(3))
        guard let kind = LinkKind(rawValue: c.args.option("kind") ?? "related") else { throw CLIError("--kind must be one of: \(LinkKind.allCases.map(\.rawValue).joined(separator: ", "))") }
        try c.store.link(from: a.id, to: b.id, kind: kind)
        c.out.emit(["from": .string(a.displayNumber), "to": .string(b.displayNumber), "kind": .string(kind.rawValue)], text: "\(a.displayNumber) \(kind.rawValue) \(b.displayNumber)")
    }

    // hatch next
    static func next(_ c: Context) throws {
        let work = try c.store.agentWork(projectId: try? c.project().id)
        let json: JSONValue = .array(work.map { ["ticket": .string($0.ticket.displayNumber), "task": .string($0.kind.rawValue), "title": .string($0.ticket.title), "type": .string($0.ticket.type.rawValue)] })
        let text = work.isEmpty ? "Nothing waiting for an agent." : work.map { "\($0.ticket.displayNumber)  \($0.kind.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \($0.ticket.title)\n    take it with: hatch take \($0.ticket.displayNumber) --agent \"Agent on \($0.ticket.displayNumber)\"" }.joined(separator: "\n")
        c.out.emit(json, text: text)
    }

    // hatch ask #151 "question" [--suggest a --suggest b] [--by Iris]
    static func ask(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let text = c.args.rest(from: 2)
        guard !text.isEmpty else { throw CLIError("Usage: hatch ask #151 \"the question\" [--suggest answer]...") }
        let q = try c.store.ask(t.id, text: text, suggestions: c.args.list("suggest"), by: c.args.option("by") ?? t.takenBy ?? "agent")
        let after = try c.store.ticket(id: t.id)!
        c.out.emit(["question": .int(q.id), "status": .string(after.status.rawValue)], text: "Asked. \(after.displayNumber) is now \(after.status.displayName); the owner will answer.")
    }

    // hatch plan #144 --files "a/b.swift,c/**" [--repo app]
    static func plan(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let files = (c.args.option("files") ?? c.args.rest(from: 2)).split(whereSeparator: { $0 == "," || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        guard !files.isEmpty else { throw CLIError("Usage: hatch plan #144 --files \"path/one.swift,folder/**\" [--repo app]") }
        var repoId: Int?
        if let role = c.args.option("repo") {
            guard let r = try c.store.repos(projectId: t.projectId).first(where: { $0.role.rawValue == role }) else { throw CLIError("No repo with role '\(role)'.") }
            repoId = r.id
        }
        let outcome = try c.store.claim(ticketId: t.id, repoId: repoId, paths: files)
        let after = try c.store.ticket(id: t.id)!
        switch outcome {
        case .granted:
            c.out.emit(["claim": "granted", "files": .int(files.count)], text: "Claim granted for \(files.count) path(s). Go ahead.")
        case .queued(let behind):
            let names = try behind.compactMap { try c.store.ticket(id: $0)?.displayNumber }
            c.out.emit(["claim": "queued", "behind": .array(names.map { .string($0) }), "status": .string(after.status.rawValue)],
                       text: "Those files are claimed by \(names.joined(separator: ", ")). \(after.displayNumber) is now \(after.status.displayName) and will resume by itself when they are free. Stop working on it now.")
        }
    }

    // hatch note #151 "text" [--kind note|comment|agent] [--by name]
    static func note(_ c: Context) throws {
        let t = try c.ticket(c.args.pos(1))
        let body = c.args.rest(from: 2)
        let kind = NoteKind(rawValue: c.args.option("kind") ?? "agent") ?? .agent
        guard kind != .ask && kind != .instruction else { throw CLIError("Only the owner sends Ask and Instruction notes; use hatch ask to question the owner.") }
        let n = try c.store.addNote(t.id, kind: kind, author: c.args.option("by") ?? t.takenBy ?? "agent", body: body)
        c.out.emit(["note": .int(n.id)], text: "Note added to \(t.displayNumber).")
    }

    // hatch search "words" [--specs]
    static func search(_ c: Context) throws {
        let q = c.args.rest(from: 1)
        guard !q.isEmpty else { throw CLIError("Usage: hatch search \"words\"") }
        let p = try? c.project()
        let tickets = try c.store.tickets(TicketFilter(projectId: p?.id, text: q, limit: 15))
        let specs = try p.map { try c.store.searchSpec(projectId: $0.id, query: q, limit: 8) } ?? []
        let json: JSONValue = ["tickets": .array(tickets.map(\.asJSON)), "specs": .array(specs.map { ["code": .string($0.code), "text": .string($0.text)] })]
        var text = tickets.map(\.oneLine).joined(separator: "\n")
        if !specs.isEmpty { text += (text.isEmpty ? "" : "\n\n") + "Spec:\n" + specs.map { "  \($0.code)  \($0.text)" }.joined(separator: "\n") }
        c.out.emit(json, text: text.isEmpty ? "No matches." : text)
    }

    // hatch admin move|resume|answer|type  -- bookkeeping for people and for Hatch itself, NOT for agents
    static func admin(_ c: Context) throws {
        switch c.args.pos(1) {
        case "move":
            let t = try c.ticket(c.args.pos(2))
            guard let s = c.args.pos(3), let status = Status(rawValue: s) else { throw CLIError("Usage: hatch admin move #151 <status> --as owner|agent|hatch") }
            let after = try c.store.move(t.id, to: status, actor: try c.actor(default: .owner), reason: c.args.option("reason"))
            c.out.emit(after.asJSON, text: after.oneLine)
        case "resume":
            let after = try c.store.resume(try c.ticket(c.args.pos(2)).id, actor: try c.actor(default: .owner))
            c.out.emit(after.asJSON, text: after.oneLine)
        case "answer":
            guard let qid = c.args.pos(2).flatMap(Int.init) else { throw CLIError("Usage: hatch admin answer <question id> \"text\"") }
            let after = try c.store.answer(questionId: qid, text: c.args.rest(from: 3))
            c.out.emit(after.asJSON, text: after.oneLine)
        case "type":
            guard let t = c.args.pos(3).flatMap(TicketType.init(rawValue:)) else { throw CLIError("Usage: hatch admin type #151 <type>") }
            let after = try c.store.changeType(try c.ticket(c.args.pos(2)).id, to: t, actor: try c.actor(default: .owner), reason: c.args.option("reason"))
            c.out.emit(after.asJSON, text: after.oneLine)
        default: throw CLIError("Usage: hatch admin move|resume|answer|type ...")
        }
    }
}

/// Plain copies of the app's turn titles for the CLI (the CLI does not link SwiftUI).
enum Theme {
    static func title(_ t: Turn) -> String {
        switch t { case .you: "Your turn"; case .agent: "Agent's turn"; case .hatch: "Hatch"; case .finished: "Finished"; case .paused: "Paused" }
    }
}
