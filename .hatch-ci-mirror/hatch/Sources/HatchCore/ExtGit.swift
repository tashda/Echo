import Foundation

// Persistence for HatchGit: workspaces (worktrees per ticket) and previews. Additive only.

public struct Workspace: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketId: Int
    public let repoId: Int
    public var path: String
    public var branch: String
    public var baseSha: String?
    public var state: String          // active, removed
    public let at: Date
}

public struct Preview: Identifiable, Equatable, Sendable {
    public let id: Int
    public var name: String           // "Preview 03"
    public var state: String          // planned, merged, conflict, discarded
    public var branch: String?        // "preview/03"
    public var builtAt: Date?
    public var log: String?
    public let at: Date
}

public struct PreviewTicket: Equatable, Sendable {
    public let previewId: Int
    public let ticketId: Int
    public var verdict: String?
    public var note: String?
}

public extension HatchStore {
    func repo(id: Int) throws -> Repo? {
        for p in try projects() { if let r = try repos(projectId: p.id).first(where: { $0.id == id }) { return r } }
        return nil
    }

    private static func workspace(_ r: Row) -> Workspace {
        Workspace(id: r.int("id")!, ticketId: r.int("ticket_id")!, repoId: r.int("repo_id")!, path: r.string("path")!,
                  branch: r.string("branch")!, baseSha: r.string("base_sha"), state: r.string("state") ?? "active", at: r.date("at") ?? Date())
    }

    /// One workspace per ticket and repo; saving again replaces the row (a removed workspace can be recreated).
    @discardableResult
    func saveWorkspace(ticketId: Int, repoId: Int, path: String, branch: String, baseSha: String?, state: String = "active") throws -> Workspace {
        try db.execute("""
            INSERT INTO workspace(ticket_id, repo_id, path, branch, base_sha, state, at) VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(ticket_id, repo_id) DO UPDATE SET path = excluded.path, branch = excluded.branch, base_sha = excluded.base_sha,
                state = excluded.state, at = excluded.at
            """, [.int(ticketId), .int(repoId), .text(path), .text(branch), .opt(baseSha), .text(state), .date(now())])
        return try workspace(ticketId: ticketId, repoId: repoId)!
    }

    func workspace(ticketId: Int, repoId: Int) throws -> Workspace? {
        try db.query("SELECT * FROM workspace WHERE ticket_id = ? AND repo_id = ?", [.int(ticketId), .int(repoId)], map: Self.workspace).first
    }

    func workspaces(ticketId: Int? = nil, includeRemoved: Bool = false) throws -> [Workspace] {
        var sql = "SELECT * FROM workspace WHERE 1=1", params: [SQLValue] = []
        if let ticketId { sql += " AND ticket_id = ?"; params.append(.int(ticketId)) }
        if !includeRemoved { sql += " AND state != 'removed'" }
        return try db.query(sql + " ORDER BY id", params, map: Self.workspace)
    }

    func setWorkspace(_ id: Int, state: String? = nil, baseSha: String? = nil) throws {
        if let state { try db.execute("UPDATE workspace SET state = ? WHERE id = ?", [.text(state), .int(id)]) }
        if let baseSha { try db.execute("UPDATE workspace SET base_sha = ? WHERE id = ?", [.text(baseSha), .int(id)]) }
    }

    // MARK: Previews

    private static func preview(_ r: Row) -> Preview {
        Preview(id: r.int("id")!, name: r.string("name")!, state: r.string("state") ?? "planned", branch: r.string("branch"),
                builtAt: r.date("built_at"), log: r.string("log"), at: r.date("at") ?? Date())
    }

    /// The next Preview number: one more than the highest used so far (discarded previews keep their number).
    func nextPreviewNumber() throws -> Int {
        try db.scalarInt("SELECT COALESCE(MAX(id), 0) + 1 FROM preview")
    }

    @discardableResult
    func createPreview(name: String, branch: String?, ticketIds: [Int]) throws -> Preview {
        try db.transaction {
            try db.execute("INSERT INTO preview(name, state, branch, at) VALUES(?,?,?,?)", [.text(name), "planned", .opt(branch), .date(now())])
            let id = Int(db.lastInsertRowID)
            for t in ticketIds { try db.execute("INSERT OR IGNORE INTO preview_ticket(preview_id, ticket_id) VALUES(?,?)", [.int(id), .int(t)]) }
            return try preview(id: id)!
        }
    }

    func preview(id: Int) throws -> Preview? {
        try db.query("SELECT * FROM preview WHERE id = ?", [.int(id)], map: Self.preview).first
    }

    func previews() throws -> [Preview] {
        try db.query("SELECT * FROM preview ORDER BY id", map: Self.preview)
    }

    func setPreview(_ id: Int, state: String, log: String? = nil, built: Bool = false) throws {
        try db.execute("UPDATE preview SET state = ?, log = COALESCE(?, log), built_at = CASE WHEN ? THEN ? ELSE built_at END WHERE id = ?",
                       [.text(state), .opt(log), .int(built ? 1 : 0), .date(now()), .int(id)])
    }

    func previewTickets(previewId: Int) throws -> [PreviewTicket] {
        try db.query("SELECT * FROM preview_ticket WHERE preview_id = ? ORDER BY rowid", [.int(previewId)]) {
            PreviewTicket(previewId: $0.int("preview_id")!, ticketId: $0.int("ticket_id")!, verdict: $0.string("verdict"), note: $0.string("note"))
        }
    }

    func setVerdict(previewId: Int, ticketId: Int, verdict: String?, note: String?) throws {
        try db.execute("UPDATE preview_ticket SET verdict = ?, note = ? WHERE preview_id = ? AND ticket_id = ?",
                       [.opt(verdict), .opt(note), .int(previewId), .int(ticketId)])
    }
}
