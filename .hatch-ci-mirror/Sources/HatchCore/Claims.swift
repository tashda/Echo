import Foundation

public struct Claim: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let repoId: Int?
    public let pathGlob: String
    public var state: String      // held, queued, stacked, released
    public let at: Date
}

public enum ClaimOutcome: Equatable, Sendable {
    case granted
    case queued(behind: [Int])    // ticket ids that hold overlapping files
}

/// File claims (decision K3): a ticket says which files it expects to touch. Overlap queues the later ticket by default,
/// or stacks it on the first. The claim is a prediction; git still decides at merge time.
public extension HatchStore {
    func claims(ticketId: Int? = nil, state: String? = nil) throws -> [Claim] {
        var sql = "SELECT * FROM claim WHERE 1=1", params: [SQLValue] = []
        if let ticketId { sql += " AND ticket_id = ?"; params.append(.int(ticketId)) }
        if let state { sql += " AND state = ?"; params.append(.text(state)) }
        return try db.query(sql + " ORDER BY id", params, map: Self.claim)
    }

    private static func claim(_ r: Row) -> Claim {
        Claim(id: r.int("id")!, ticketId: r.int("ticket_id")!, repoId: r.int("repo_id"), pathGlob: r.string("path_glob")!, state: r.string("state")!, at: r.date("at")!)
    }

    /// Declares the files a ticket will touch (the `hatch plan` command).
    @discardableResult
    func claim(ticketId: Int, repoId: Int?, paths: [String]) throws -> ClaimOutcome {
        try db.transaction {
            guard let t = try ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            let uniquePaths = Array(Set(paths)).sorted()
            let behind = try conflictingTickets(ticketId: ticketId, repoId: repoId, paths: uniquePaths)
            let state = behind.isEmpty ? "held" : "queued"
            try db.execute("DELETE FROM claim WHERE ticket_id = ? AND repo_id IS ? AND state != 'released'", [.int(ticketId), .opt(repoId)])
            for p in uniquePaths {
                try db.execute("INSERT INTO claim(ticket_id, repo_id, path_glob, state, at) VALUES(?,?,?,?,?)", [.int(ticketId), .opt(repoId), .text(p), .text(state), .date(now())])
            }
            try record(ticketId, actor: "hatch", kind: "claim", payload: ["paths": .array(uniquePaths.map { .string($0) }), "state": .string(state), "behind": .array(behind.map { .int($0) })])
            if behind.isEmpty { return .granted }
            if Workflow.isAllowed(type: t.type, from: t.status, to: .blocked, actor: .hatch) {
                let names = try behind.compactMap { try ticket(id: $0)?.displayNumber }.joined(separator: ", ")
                try move(ticketId, to: .blocked, actor: .hatch, reason: "waits for \(names) (same files)")
            }
            return .queued(behind: behind)
        }
    }

    private func conflictingTickets(ticketId: Int, repoId: Int?, paths: [String]) throws -> [Int] {
        let others = try db.query("SELECT * FROM claim WHERE ticket_id != ? AND state IN ('held','stacked') AND repo_id IS ?", [.int(ticketId), .opt(repoId)], map: Self.claim)
        var ids: [Int] = []
        for o in others where !ids.contains(o.ticketId) && paths.contains(where: { Glob.mayOverlap($0, o.pathGlob) }) { ids.append(o.ticketId) }
        return ids
    }

    /// "Stack on #144": the later ticket proceeds on the same files as the first, one commit per ticket.
    func stack(ticketId: Int, onto baseId: Int) throws {
        try db.transaction {
            try db.execute("UPDATE claim SET state = 'stacked' WHERE ticket_id = ? AND state = 'queued'", [.int(ticketId)])
            try record(ticketId, actor: "owner", kind: "stack", payload: ["onto": .int(baseId)])
            if let t = try ticket(id: ticketId), t.status == .blocked { try resume(ticketId, actor: .hatch) }
        }
    }

    /// Frees a ticket's files and wakes the tickets that were waiting for them.
    func releaseClaims(ticketId: Int) throws {
        try db.transaction {
            try db.execute("UPDATE claim SET state = 'released' WHERE ticket_id = ? AND state != 'released'", [.int(ticketId)])
            let waiting = try db.query("SELECT DISTINCT ticket_id, repo_id FROM claim WHERE state = 'queued'") { ($0.int("ticket_id")!, $0.int("repo_id")) }
            for (waitingId, repoId) in waiting {
                let paths = try claims(ticketId: waitingId, state: "queued").filter { $0.repoId == repoId }.map(\.pathGlob)
                if try conflictingTickets(ticketId: waitingId, repoId: repoId, paths: paths).isEmpty {
                    try db.execute("UPDATE claim SET state = 'held' WHERE ticket_id = ? AND state = 'queued' AND repo_id IS ?", [.int(waitingId), .opt(repoId)])
                    try record(waitingId, actor: "hatch", kind: "claim-granted", payload: ["after": .int(ticketId)])
                    if let w = try ticket(id: waitingId), w.status == .blocked, w.prevStatus != nil { try resume(waitingId, actor: .hatch) }
                }
            }
        }
    }
}
