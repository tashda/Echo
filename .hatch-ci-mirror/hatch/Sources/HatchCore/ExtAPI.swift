import Foundation

// Additive store functions for the Stage API (decision S3): idempotency keys, Stage sessions, accept and send back.
// The tables are created on first use with IF NOT EXISTS, so this file does not touch the numbered migrations.

public struct StageSession: Equatable, Sendable {
    public let ticketId: Int
    public let revision: Int
    public let pid: Int?
    public let state: String
    public let lastSeen: Date
}

public enum SendBackReason: String, CaseIterable, Sendable {
    case needsMoreOptions = "needs-more-options"
    case changeOption = "change-option"
    case differentDirection = "different-direction"
}

public extension HatchStore {
    /// Creates the small tables the API needs. Safe to call many times.
    func ensureAPITables() throws {
        try db.execute("""
            CREATE TABLE IF NOT EXISTS api_request(
                seq INTEGER PRIMARY KEY,
                key TEXT NOT NULL UNIQUE,
                status INTEGER NOT NULL,
                body TEXT NOT NULL,
                at REAL NOT NULL
            )
            """)
    }

    /// The answer we gave the first time for this idempotency key, so a replayed request changes nothing.
    func storedResponse(forKey key: String) throws -> (status: Int, body: String)? {
        try db.query("SELECT status, body FROM api_request WHERE key = ?", [.text(key)]) { ($0.int("status")!, $0.string("body") ?? "") }.first
            .map { (status: $0.0, body: $0.1) }
    }

    /// Remembers the answer for a key and forgets all but the newest `limit` keys.
    func rememberResponse(key: String, status: Int, body: String, limit: Int = 1000) throws {
        try db.transaction {
            try db.execute("INSERT OR REPLACE INTO api_request(key, status, body, at) VALUES(?,?,?,?)",
                           [.text(key), .int(status), .text(body), .date(now())])
            try db.execute("DELETE FROM api_request WHERE seq NOT IN (SELECT seq FROM api_request ORDER BY seq DESC LIMIT ?)", [.int(limit)])
        }
    }

    /// One row per running Stage window (ticket + pid). The heartbeat keeps it fresh.
    func upsertStageSession(ticketId: Int, revision: Int, pid: Int?, state: String) throws {
        try db.transaction {
            let t = now()
            let existing = try db.query("SELECT id FROM stage_session WHERE ticket_id = ? AND pid IS ?", [.int(ticketId), .opt(pid)]) { $0.int("id")! }.first
            if let existing {
                try db.execute("UPDATE stage_session SET revision = ?, state = ?, last_seen = ? WHERE id = ?",
                               [.int(revision), .text(state), .date(t), .int(existing)])
            } else {
                try db.execute("INSERT INTO stage_session(ticket_id, revision, pid, state, last_seen, at) VALUES(?,?,?,?,?,?)",
                               [.int(ticketId), .int(revision), .opt(pid), .text(state), .date(t), .date(t)])
            }
        }
    }

    func stageSessions(ticketId: Int) throws -> [StageSession] {
        try db.query("SELECT * FROM stage_session WHERE ticket_id = ? ORDER BY last_seen DESC, id DESC", [.int(ticketId)]) {
            StageSession(ticketId: $0.int("ticket_id")!, revision: $0.int("revision") ?? 1, pid: $0.int("pid"),
                         state: $0.string("state") ?? "building", lastSeen: $0.date("last_seen") ?? Date(timeIntervalSince1970: 0))
        }
    }

    /// Accept from the Stage: stores the final choices, moves Your call to Accepted (owner only) and records a decision.
    /// All or nothing: an illegal move leaves the picks untouched.
    @discardableResult
    func acceptProposal(ticketId: Int, choices: [String: String] = [:]) throws -> (ticket: Ticket, decisionId: Int, summary: String) {
        try db.transaction {
            guard let before = try ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            for topic in choices.keys.sorted() { try setPick(ticketId: ticketId, topic: topic, choice: choices[topic]!) }
            let moved = try move(ticketId, to: .accepted, actor: .owner, reason: "accepted")
            let picks = try picks(ticketId: ticketId)
            var summary = "Accepted \"\(before.title)\""
            if picks.isEmpty { summary += " without explicit picks." }
            else {
                summary += ": " + picks.map { p in "\(p.topic) = \(p.choice)" + (p.note.map { " (\($0))" } ?? "") }.joined(separator: "; ") + "."
            }
            let id = try recordDecision(ticketId: ticketId, summary: summary)
            return (moved, id, summary)
        }
    }

    /// Send back from the Stage (decision H17): Your call -> Revising, the owner's note kept as an instruction for the agent.
    @discardableResult
    func sendBackProposal(ticketId: Int, reason: SendBackReason, note: String) throws -> Ticket {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw StoreError.invalid("Say what to change when you send a Proposal back.") }
        return try db.transaction {
            let moved = try move(ticketId, to: .revising, actor: .owner, reason: reason.rawValue)
            try addNote(ticketId, kind: .instruction, author: "owner", body: text, context: ["reason": .string(reason.rawValue)])
            return moved
        }
    }
}
