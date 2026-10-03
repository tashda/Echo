import Foundation

// MARK: Events, notes, questions, links, attachments, search

public extension HatchStore {
    func record(_ ticketId: Int, actor: String, kind: String, payload: JSONValue = [:]) throws {
        try db.execute("INSERT INTO event(ticket_id, at, actor, kind, payload) VALUES(?,?,?,?,?)",
                       [.int(ticketId), .date(now()), .text(actor), .text(kind), .text(payload.jsonString())])
    }

    func events(ticketId: Int, kinds: [String]? = nil) throws -> [Event] {
        var sql = "SELECT * FROM event WHERE ticket_id = ?", params: [SQLValue] = [.int(ticketId)]
        if let kinds, !kinds.isEmpty { sql += " AND kind IN (\(kinds.map { _ in "?" }.joined(separator: ",")))"; params += kinds.map { .text($0) } }
        return try db.query(sql + " ORDER BY at, id", params) {
            Event(id: $0.int("id")!, ticketId: $0.int("ticket_id")!, at: $0.date("at")!, actor: $0.string("actor")!,
                  kind: $0.string("kind")!, payload: JSONValue.parse($0.string("payload") ?? "{}"))
        }
    }

    // Notes

    @discardableResult
    func addNote(_ ticketId: Int, kind: NoteKind, author: String, body: String, context: JSONValue? = nil, ghCommentId: Int? = nil, at: Date? = nil) throws -> Note {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw StoreError.invalid("A note cannot be empty.") }
        return try db.transaction {
            guard let t = try ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            try db.execute("INSERT INTO note(ticket_id, kind, author, body, at, gh_comment_id, context_json) VALUES(?,?,?,?,?,?,?)",
                           [.int(ticketId), .text(kind.rawValue), .text(author), .text(text), .date(at ?? now()), .opt(ghCommentId), .opt(context?.jsonString())])
            let id = Int(db.lastInsertRowID)
            try db.execute("UPDATE ticket SET updated_at = ? WHERE id = ?", [.date(now()), .int(ticketId)])
            try indexTicket(ticketId)
            try record(ticketId, actor: author, kind: "note", payload: ["kind": .string(kind.rawValue), "note": .int(id)])
            // An Ask moves the turn to the agent (decision F4); an Instruction on a Proposal becomes a revision request.
            if kind == .ask || kind == .instruction, t.status == .yourCall, t.type != .question {
                try move(ticketId, to: .revising, actor: .owner, reason: kind == .ask ? "ask" : "instruction")
            }
            if ghCommentId == nil && kind != .system && t.status != .draft {
                try enqueue(op: "issue.comment", ticketId: ticketId, payload: ["note": .int(id), "body": .string(Self.commentBody(kind: kind, author: author, text: text))])
            }
            return try notes(ticketId: ticketId).first { $0.id == id }!
        }
    }

    static func commentBody(kind: NoteKind, author: String, text: String) -> String {
        switch kind {
        case .comment: return text
        case .agent: return "**\(author)**\n\n\(text)"
        default: return "**\(kind.rawValue.capitalized) from \(author)**\n\n\(text)"
        }
    }

    func notes(ticketId: Int) throws -> [Note] {
        try db.query("SELECT * FROM note WHERE ticket_id = ? ORDER BY at, id", [.int(ticketId)]) {
            Note(id: $0.int("id")!, ticketId: $0.int("ticket_id")!, kind: NoteKind(rawValue: $0.string("kind")!) ?? .comment,
                 author: $0.string("author")!, body: $0.string("body")!, at: $0.date("at")!, ghCommentId: $0.int("gh_comment_id"),
                 context: $0.string("context_json").map(JSONValue.parse))
        }
    }

    // Questions (Needs answers, decision E4)

    @discardableResult
    func ask(_ ticketId: Int, text: String, suggestions: [String] = [], by: String, actor: Actor = .agent) throws -> Question {
        try db.transaction {
            guard let t = try ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            try db.execute("INSERT INTO question(ticket_id, text, suggestions_json, asked_by, at) VALUES(?,?,?,?,?)",
                           [.int(ticketId), .text(text), .text(JSONValue.array(suggestions.map { .string($0) }).jsonString()), .text(by), .date(now())])
            let id = Int(db.lastInsertRowID)
            try record(ticketId, actor: by, kind: "question", payload: ["question": .int(id), "text": .string(text)])
            if t.status != .needsAnswers && Workflow.isAllowed(type: t.type, from: t.status, to: .needsAnswers, actor: actor) {
                try move(ticketId, to: .needsAnswers, actor: actor, reason: "question")
            }
            return try questions(ticketId: ticketId).first { $0.id == id }!
        }
    }

    func questions(ticketId: Int, openOnly: Bool = false) throws -> [Question] {
        try db.query("SELECT * FROM question WHERE ticket_id = ?\(openOnly ? " AND answer IS NULL" : "") ORDER BY at, id", [.int(ticketId)]) {
            Question(id: $0.int("id")!, ticketId: $0.int("ticket_id")!, text: $0.string("text")!,
                     suggestions: (JSONValue.parse($0.string("suggestions_json") ?? "[]").arrayValue ?? []).compactMap { $0.stringValue },
                     askedBy: $0.string("asked_by")!, at: $0.date("at")!, answer: $0.string("answer"), answeredAt: $0.date("answered_at"))
        }
    }

    /// Records an answer. When the last open question is answered the ticket goes to Ready, by Hatch, not by an agent.
    @discardableResult
    func answer(questionId: Int, text: String) throws -> Ticket {
        try db.transaction {
            guard let ticketId = try db.query("SELECT ticket_id FROM question WHERE id = ?", [.int(questionId)], map: { $0.int("ticket_id") }).first ?? nil else {
                throw StoreError.notFound("question \(questionId)")
            }
            try db.execute("UPDATE question SET answer = ?, answered_at = ? WHERE id = ?", [.text(text), .date(now()), .int(questionId)])
            try record(ticketId, actor: "owner", kind: "answer", payload: ["question": .int(questionId)])
            try db.execute("UPDATE ticket SET updated_at = ? WHERE id = ?", [.date(now()), .int(ticketId)])
            try indexTicket(ticketId)
            let t = try ticket(id: ticketId)!
            if t.status == .needsAnswers, try questions(ticketId: ticketId, openOnly: true).isEmpty {
                return try move(ticketId, to: .ready, actor: .hatch, reason: "all questions answered")
            }
            return t
        }
    }

    // Links (decision E5)

    func link(from: Int, to: Int, kind: LinkKind) throws {
        guard from != to else { throw StoreError.invalid("A ticket cannot link to itself.") }
        try db.execute("INSERT OR IGNORE INTO ticket_link(from_id, to_id, kind) VALUES(?,?,?)", [.int(from), .int(to), .text(kind.rawValue)])
        try record(from, actor: "owner", kind: "link", payload: ["to": .int(to), "kind": .string(kind.rawValue)])
    }

    func unlink(from: Int, to: Int, kind: LinkKind) throws {
        try db.execute("DELETE FROM ticket_link WHERE from_id = ? AND to_id = ? AND kind = ?", [.int(from), .int(to), .text(kind.rawValue)])
    }

    /// Links in both directions, with the direction made explicit.
    func links(ticketId: Int) throws -> [(link: TicketLink, outgoing: Bool)] {
        let out = try db.query("SELECT * FROM ticket_link WHERE from_id = ?", [.int(ticketId)]) { TicketLink(fromId: $0.int("from_id")!, toId: $0.int("to_id")!, kind: LinkKind(rawValue: $0.string("kind")!) ?? .related) }.map { ($0, true) }
        let inc = try db.query("SELECT * FROM ticket_link WHERE to_id = ?", [.int(ticketId)]) { TicketLink(fromId: $0.int("from_id")!, toId: $0.int("to_id")!, kind: LinkKind(rawValue: $0.string("kind")!) ?? .related) }.map { ($0, false) }
        return out + inc
    }

    /// Open tickets that block this one (a Blocks link pointing at it).
    func openBlockers(ticketId: Int) throws -> [Ticket] {
        try db.query("""
            SELECT t.* FROM ticket_link l JOIN ticket t ON t.id = l.from_id
            WHERE l.to_id = ? AND l.kind = 'blocks' AND t.status NOT IN ('done','dropped','merged')
            """, [.int(ticketId)]) { HatchStore.ticket($0) }
    }

    // Attachments (decision M3)

    @discardableResult
    func addAttachment(_ ticketId: Int, path: String, sha: String? = nil, kind: String = "screenshot", caption: String? = nil) throws -> Attachment {
        try db.execute("INSERT INTO attachment(ticket_id, path, sha, kind, caption, at) VALUES(?,?,?,?,?,?)",
                       [.int(ticketId), .text(path), .opt(sha), .text(kind), .opt(caption), .date(now())])
        try record(ticketId, actor: "owner", kind: "attachment", payload: ["path": .string(path)])
        return try attachments(ticketId: ticketId).last!
    }

    func attachments(ticketId: Int) throws -> [Attachment] {
        try db.query("SELECT * FROM attachment WHERE ticket_id = ? ORDER BY at, id", [.int(ticketId)]) {
            Attachment(id: $0.int("id")!, ticketId: $0.int("ticket_id")!, path: $0.string("path")!, sha: $0.string("sha"),
                       kind: $0.string("kind") ?? "screenshot", caption: $0.string("caption"), at: $0.date("at")!)
        }
    }

    // Search (decisions E2 and M4)

    static let stopWords: Set<String> = ["the", "a", "an", "and", "or", "of", "to", "in", "on", "for", "is", "it", "this", "that", "with", "as", "at", "be", "by", "we", "are", "was", "not", "but", "from", "when", "how", "too", "i"]

    static func tokens(_ text: String) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for raw in text.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
            let w = String(raw)
            if w.count < 2 || stopWords.contains(w) || seen.contains(w) { continue }
            seen.insert(w); out.append(w)
        }
        return out
    }

    /// A user query: every word must match (prefix match on each).
    static func ftsQuery(_ text: String) -> String? {
        let t = tokens(text)
        return t.isEmpty ? nil : t.map { "\"\($0)\"*" }.joined(separator: " ")
    }

    /// Re-reads the ticket and its notes into the search index.
    func indexTicket(_ id: Int) throws {
        guard let t = try ticket(id: id) else { return }
        let notes = try db.query("SELECT body FROM note WHERE ticket_id = ? ORDER BY at", [.int(id)]) { $0.string("body") ?? "" }.joined(separator: "\n")
        let answers = try db.query("SELECT text, answer FROM question WHERE ticket_id = ?", [.int(id)]) { "\($0.string("text") ?? "") \($0.string("answer") ?? "")" }.joined(separator: "\n")
        try db.execute("DELETE FROM ticket_fts WHERE ticket_id = ?", [.int(id)])
        try db.execute("INSERT INTO ticket_fts(title, body, notes, ticket_id) VALUES(?,?,?,?)", [.text(t.title), .text(t.body), .text(notes + "\n" + answers), .int(id)])
    }

    /// Free, local, no tokens: tickets that look like this text (composer hints and Iris's candidate list).
    func similarTickets(projectId: Int?, title: String, body: String = "", excluding: Int? = nil, limit: Int = 8) throws -> [(ticket: Ticket, score: Double)] {
        let words = Array(Self.tokens(title + " " + body).prefix(14))
        guard !words.isEmpty else { return [] }
        let match = words.map { "\"\($0)\"" }.joined(separator: " OR ")
        var sql = "SELECT t.*, bm25(ticket_fts) AS score FROM ticket_fts JOIN ticket t ON t.id = ticket_fts.ticket_id WHERE ticket_fts MATCH ?"
        var params: [SQLValue] = [.text(match)]
        if let projectId { sql += " AND t.project_id = ?"; params.append(.int(projectId)) }
        if let excluding { sql += " AND t.id != ?"; params.append(.int(excluding)) }
        sql += " ORDER BY score LIMIT ?"; params.append(.int(limit))
        return try db.query(sql, params) { (HatchStore.ticket($0), -($0.double("score") ?? 0)) }
    }

    // Specs (decision L3)

    func upsertSpecItems(projectId: Int, items: [(code: String, area: String?, text: String, source: String?)]) throws {
        try db.transaction {
            for i in items {
                try db.execute("""
                    INSERT INTO spec_item(project_id, code, area, text, source) VALUES(?,?,?,?,?)
                    ON CONFLICT(project_id, code) DO UPDATE SET area = excluded.area, text = excluded.text, source = excluded.source
                    """, [.int(projectId), .text(i.code), .opt(i.area), .text(i.text), .opt(i.source)])
                let id = try db.query("SELECT id FROM spec_item WHERE project_id = ? AND code = ?", [.int(projectId), .text(i.code)]) { $0.int("id")! }.first!
                try db.execute("DELETE FROM spec_fts WHERE spec_id = ?", [.int(id)])
                try db.execute("INSERT INTO spec_fts(code, area, text, spec_id) VALUES(?,?,?,?)", [.text(i.code), .opt(i.area), .text(i.text), .int(id)])
            }
        }
    }

    func specItems(projectId: Int, area: String? = nil) throws -> [SpecItem] {
        var sql = "SELECT * FROM spec_item WHERE project_id = ?", params: [SQLValue] = [.int(projectId)]
        if let area { sql += " AND area = ?"; params.append(.text(area)) }
        return try db.query(sql + " ORDER BY code", params, map: Self.specItem)
    }

    func searchSpec(projectId: Int, query: String, limit: Int = 8) throws -> [SpecItem] {
        let words = Array(Self.tokens(query).prefix(14))
        guard !words.isEmpty else { return [] }
        return try db.query("""
            SELECT s.* FROM spec_fts JOIN spec_item s ON s.id = spec_fts.spec_id
            WHERE spec_fts MATCH ? AND s.project_id = ? ORDER BY bm25(spec_fts) LIMIT ?
            """, [.text(words.map { "\"\($0)\"" }.joined(separator: " OR ")), .int(projectId), .int(limit)], map: Self.specItem)
    }

    private static func specItem(_ r: Row) -> SpecItem {
        SpecItem(id: r.int("id")!, projectId: r.int("project_id")!, code: r.string("code")!, area: r.string("area"), text: r.string("text")!, source: r.string("source"))
    }

    // Agent runs and cost (decision K5)

    func startRun(ticketId: Int?, agent: String, step: String?) throws -> Int {
        try db.execute("INSERT INTO agent_run(ticket_id, agent, step, started_at) VALUES(?,?,?,?)", [.opt(ticketId), .text(agent), .opt(step), .date(now())])
        return Int(db.lastInsertRowID)
    }

    func endRun(_ id: Int, tokensIn: Int, tokensOut: Int, outcome: String) throws {
        try db.execute("UPDATE agent_run SET tokens_in = ?, tokens_out = ?, ended_at = ?, outcome = ? WHERE id = ?",
                       [.int(tokensIn), .int(tokensOut), .date(now()), .text(outcome), .int(id)])
    }

    func tokenTotals(ticketId: Int? = nil, since: Date? = nil) throws -> (input: Int, output: Int) {
        var sql = "SELECT COALESCE(SUM(tokens_in),0) AS i, COALESCE(SUM(tokens_out),0) AS o FROM agent_run WHERE 1=1", params: [SQLValue] = []
        if let ticketId { sql += " AND ticket_id = ?"; params.append(.int(ticketId)) }
        if let since { sql += " AND started_at >= ?"; params.append(.date(since)) }
        return try db.query(sql, params) { ($0.int("i") ?? 0, $0.int("o") ?? 0) }.first ?? (0, 0)
    }

    // Decisions (Decisions library, decision N1)

    @discardableResult
    func recordDecision(ticketId: Int, summary: String, specCodes: [String] = []) throws -> Int {
        try db.execute("INSERT INTO decision(ticket_id, summary, spec_codes_json, at) VALUES(?,?,?,?)",
                       [.int(ticketId), .text(summary), .text(JSONValue.array(specCodes.map { .string($0) }).jsonString()), .date(now())])
        return Int(db.lastInsertRowID)
    }

    func decisions(projectId: Int? = nil) throws -> [(ticket: Ticket, summary: String, specCodes: [String], at: Date)] {
        var sql = "SELECT d.summary, d.spec_codes_json, d.at AS dat, t.* FROM decision d JOIN ticket t ON t.id = d.ticket_id"
        var params: [SQLValue] = []
        if let projectId { sql += " WHERE t.project_id = ?"; params.append(.int(projectId)) }
        return try db.query(sql + " ORDER BY d.at DESC", params) {
            (HatchStore.ticket($0), $0.string("summary") ?? "",
             (JSONValue.parse($0.string("spec_codes_json") ?? "[]").arrayValue ?? []).compactMap { $0.stringValue }, $0.date("dat") ?? Date())
        }
    }
}
