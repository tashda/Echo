import Foundation

public struct Pick: Equatable, Sendable { public let topic: String; public let choice: String; public let note: String?; public let at: Date }
public struct Verdict: Equatable, Sendable { public let topic: String; public let option: String; public let verdict: String; public let note: String? }
public struct PinnedNote: Identifiable, Equatable, Sendable {
    public let id: Int; public let option: String?; public let x: Double?; public let y: Double?
    public let scenario: String?; public let appearance: String?; public let corners: Int?; public let zoom: Double?
    public let text: String; public let at: Date
}
public struct Revision: Equatable, Sendable { public let n: Int; public let summary: String; public let added: [String]; public let at: Date }

/// State of a Proposal while the owner judges it: manifest, picks, Pick/Maybe/No verdicts, pinned notes, revisions.
/// Written only through Hatch (decision S3), whether the owner clicked in the Stage app or in Hatch itself.
public extension HatchStore {
    func saveProposal(ticketId: Int, manifestJSON: String) throws {
        let revision = try ticket(id: ticketId)?.revision ?? 1
        try db.execute("""
            INSERT INTO proposal(ticket_id, revision, manifest_json, updated_at) VALUES(?,?,?,?)
            ON CONFLICT(ticket_id) DO UPDATE SET revision = excluded.revision, manifest_json = excluded.manifest_json, updated_at = excluded.updated_at
            """, [.int(ticketId), .int(revision), .text(manifestJSON), .date(now())])
    }

    func proposalManifest(ticketId: Int) throws -> String? {
        try db.query("SELECT manifest_json FROM proposal WHERE ticket_id = ?", [.int(ticketId)]) { $0.string("manifest_json") }.first ?? nil
    }

    func setPick(ticketId: Int, topic: String, choice: String, note: String? = nil) throws {
        try db.execute("""
            INSERT INTO pick(ticket_id, topic, choice, note, at) VALUES(?,?,?,?,?)
            ON CONFLICT(ticket_id, topic) DO UPDATE SET choice = excluded.choice, note = excluded.note, at = excluded.at
            """, [.int(ticketId), .text(topic), .text(choice), .opt(note), .date(now())])
        try record(ticketId, actor: "owner", kind: "pick", payload: ["topic": .string(topic), "choice": .string(choice)])
    }

    func picks(ticketId: Int) throws -> [Pick] {
        try db.query("SELECT * FROM pick WHERE ticket_id = ? ORDER BY topic", [.int(ticketId)]) { Pick(topic: $0.string("topic")!, choice: $0.string("choice")!, note: $0.string("note"), at: $0.date("at")!) }
    }

    func setVerdict(ticketId: Int, topic: String, option: String, verdict: String, note: String? = nil) throws {
        guard ["pick", "maybe", "no"].contains(verdict) else { throw StoreError.invalid("A verdict is pick, maybe or no.") }
        try db.execute("""
            INSERT INTO verdict(ticket_id, topic, option, verdict, note, at) VALUES(?,?,?,?,?,?)
            ON CONFLICT(ticket_id, topic, option) DO UPDATE SET verdict = excluded.verdict, note = excluded.note, at = excluded.at
            """, [.int(ticketId), .text(topic), .text(option), .text(verdict), .opt(note), .date(now())])
        try record(ticketId, actor: "owner", kind: "verdict", payload: ["topic": .string(topic), "option": .string(option), "verdict": .string(verdict)])
    }

    /// The owner toggled a verdict off in the Stage.
    func clearVerdict(ticketId: Int, topic: String, option: String) throws {
        try db.execute("DELETE FROM verdict WHERE ticket_id = ? AND topic = ? AND option = ?", [.int(ticketId), .text(topic), .text(option)])
        try record(ticketId, actor: "owner", kind: "verdict", payload: ["topic": .string(topic), "option": .string(option), "verdict": .string("none")])
    }

    func verdicts(ticketId: Int) throws -> [Verdict] {
        try db.query("SELECT * FROM verdict WHERE ticket_id = ? ORDER BY topic, option", [.int(ticketId)]) { Verdict(topic: $0.string("topic")!, option: $0.string("option")!, verdict: $0.string("verdict")!, note: $0.string("note")) }
    }

    @discardableResult
    func addPin(ticketId: Int, option: String?, x: Double?, y: Double?, scenario: String?, appearance: String?, corners: Int?, zoom: Double?, text: String) throws -> Int {
        try db.execute("INSERT INTO pinned_note(ticket_id, option, x, y, scenario, appearance, corners, zoom, text, at) VALUES(?,?,?,?,?,?,?,?,?,?)",
                       [.int(ticketId), .opt(option), .opt(x), .opt(y), .opt(scenario), .opt(appearance), .opt(corners), .opt(zoom), .text(text), .date(now())])
        return Int(db.lastInsertRowID)
    }

    func pins(ticketId: Int) throws -> [PinnedNote] {
        try db.query("SELECT * FROM pinned_note WHERE ticket_id = ? ORDER BY id", [.int(ticketId)]) {
            PinnedNote(id: $0.int("id")!, option: $0.string("option"), x: $0.double("x"), y: $0.double("y"), scenario: $0.string("scenario"),
                       appearance: $0.string("appearance"), corners: $0.int("corners"), zoom: $0.double("zoom"), text: $0.string("text")!, at: $0.date("at")!)
        }
    }

    /// The agent hands in a new revision after the owner sent the Proposal back. Old options stay (decision H15).
    @discardableResult
    func recordRevision(ticketId: Int, summary: String, added: [String]) throws -> Int {
        let n = try bumpRevision(ticketId)
        try db.execute("INSERT INTO revision(ticket_id, n, summary, added_json, at) VALUES(?,?,?,?,?)",
                       [.int(ticketId), .int(n), .text(summary), .text(JSONValue.array(added.map { .string($0) }).jsonString()), .date(now())])
        try record(ticketId, actor: "agent", kind: "revision", payload: ["n": .int(n), "summary": .string(summary)])
        return n
    }

    func revisions(ticketId: Int) throws -> [Revision] {
        try db.query("SELECT * FROM revision WHERE ticket_id = ? ORDER BY n", [.int(ticketId)]) {
            Revision(n: $0.int("n")!, summary: $0.string("summary")!, added: (JSONValue.parse($0.string("added_json") ?? "[]").arrayValue ?? []).compactMap { $0.stringValue }, at: $0.date("at")!)
        }
    }
}
