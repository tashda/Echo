import Foundation

/// Everything that must reach GitHub is queued here in the same transaction as the change itself (decision: the app does the bookkeeping,
/// and every sync is recorded). `HatchSync` drains the queue.
public extension HatchStore {
    /// The labels Hatch manages on an issue: type, status, project and area.
    func labels(for t: Ticket) throws -> [String] {
        var out = [t.type.label, t.status.label]
        if let p = try project(id: t.projectId) { out.append("project:\(p.key)") }
        if let a = t.area, !a.isEmpty { out.append("area:\(Self.slug(a))") }
        return out
    }

    static func slug(_ s: String) -> String {
        let lowered = s.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return String(lowered).split(separator: "-", omittingEmptySubsequences: true).joined(separator: "-")
    }

    @discardableResult
    func enqueue(op: String, ticketId: Int?, payload: JSONValue) throws -> Int {
        try db.execute("INSERT INTO sync_log(ticket_id, op, payload, direction, state, attempt, next_at, at) VALUES(?,?,?,?,?,?,?,?)",
                       [.opt(ticketId), .text(op), .text(payload.jsonString()), "push", "pending", 0, 0, .date(now())])
        return Int(db.lastInsertRowID)
    }

    private func pendingOp(_ op: String, ticketId: Int) throws -> (id: Int, payload: JSONValue)? {
        try db.query("SELECT id, payload FROM sync_log WHERE ticket_id = ? AND op = ? AND state = 'pending' ORDER BY id LIMIT 1", [.int(ticketId), .text(op)]) {
            ($0.int("id")!, JSONValue.parse($0.string("payload") ?? "{}"))
        }.first
    }

    private func rewrite(_ id: Int, _ payload: JSONValue) throws {
        try db.execute("UPDATE sync_log SET payload = ?, at = ? WHERE id = ?", [.text(payload.jsonString()), .date(now()), .int(id)])
    }

    func enqueueCreateIssue(_ id: Int) throws {
        guard let t = try ticket(id: id), t.ghNumber == nil else { return }
        if try pendingOp("issue.create", ticketId: id) != nil { return }
        try enqueue(op: "issue.create", ticketId: id, payload: [
            "title": .string(t.title), "body": .string(t.body),
            "labels": .array(try labels(for: t).map { .string($0) }),
        ])
    }

    func enqueueLabels(_ id: Int) throws {
        guard let t = try ticket(id: id) else { return }
        let labels = JSONValue.array(try self.labels(for: t).map { .string($0) })
        if let create = try pendingOp("issue.create", ticketId: id) {
            var obj = create.payload.objectValue ?? [:]; obj["labels"] = labels
            try rewrite(create.id, .object(obj)); return
        }
        if let existing = try pendingOp("issue.labels", ticketId: id) { try rewrite(existing.id, ["labels": labels]); return }
        try enqueue(op: "issue.labels", ticketId: id, payload: ["labels": labels])
    }

    func enqueueUpdate(_ id: Int, title: String?, body: String?) throws {
        if let create = try pendingOp("issue.create", ticketId: id) {
            var obj = create.payload.objectValue ?? [:]
            if let title { obj["title"] = .string(title) }
            if let body { obj["body"] = .string(body) }
            try rewrite(create.id, .object(obj)); return
        }
        var payload: [String: JSONValue] = [:]
        if let title { payload["title"] = .string(title) }
        if let body { payload["body"] = .string(body) }
        if let existing = try pendingOp("issue.update", ticketId: id) {
            var obj = existing.payload.objectValue ?? [:]; for (k, v) in payload { obj[k] = v }
            try rewrite(existing.id, .object(obj))
        } else { try enqueue(op: "issue.update", ticketId: id, payload: .object(payload)) }
    }

    func enqueueClose(_ id: Int, reason: String) throws {
        try enqueue(op: "issue.close", ticketId: id, payload: ["reason": .string(reason)])
    }

    /// Records the GitHub number once the issue exists.
    func applyIssueCreated(ticketId: Int, ghNumber: Int, updatedAt: String? = nil) throws {
        try db.execute("UPDATE ticket SET gh_number = ?, gh_updated_at = ? WHERE id = ?", [.int(ghNumber), .opt(updatedAt), .int(ticketId)])
        try record(ticketId, actor: "hatch", kind: "synced", payload: ["issue": .int(ghNumber)])
    }

    // MARK: Reading and draining the queue

    private static func syncOp(_ r: Row) -> SyncOp {
        SyncOp(id: r.int("id")!, ticketId: r.int("ticket_id"), op: r.string("op")!, payload: JSONValue.parse(r.string("payload") ?? "{}"),
               direction: r.string("direction") ?? "push", state: r.string("state") ?? "pending", attempt: r.int("attempt") ?? 0,
               nextAt: r.double("next_at") ?? 0, error: r.string("error"), at: r.date("at") ?? Date(), doneAt: r.date("done_at"))
    }

    /// Operations due now, oldest first. A ticket's operations are returned in order, so create always precedes labels and comments.
    func pendingSync(limit: Int = 50) throws -> [SyncOp] {
        try db.query("SELECT * FROM sync_log WHERE state = 'pending' AND next_at <= ? ORDER BY id LIMIT ?", [.double(now().timeIntervalSince1970), .int(limit)], map: Self.syncOp)
    }

    func syncLog(state: String? = nil, limit: Int = 200) throws -> [SyncOp] {
        if let state { return try db.query("SELECT * FROM sync_log WHERE state = ? ORDER BY id DESC LIMIT ?", [.text(state), .int(limit)], map: Self.syncOp) }
        return try db.query("SELECT * FROM sync_log ORDER BY id DESC LIMIT ?", [.int(limit)], map: Self.syncOp)
    }

    func syncCounts() throws -> (pending: Int, failed: Int) {
        let p = try db.scalarInt("SELECT COUNT(*) FROM sync_log WHERE state = 'pending'")
        let f = try db.scalarInt("SELECT COUNT(*) FROM sync_log WHERE state = 'failed'")
        return (p, f)
    }

    func markSyncDone(_ id: Int) throws {
        try db.execute("UPDATE sync_log SET state = 'done', done_at = ?, error = NULL WHERE id = ?", [.date(now()), .int(id)])
    }

    /// A failed push is retried with exponential backoff (30 s, 1 min, 2 min ... up to 1 h). After `maxAttempts` it stays Failed until retried by hand.
    func markSyncFailed(_ id: Int, error: String, maxAttempts: Int = 8) throws {
        let attempt = (try db.query("SELECT attempt FROM sync_log WHERE id = ?", [.int(id)]) { $0.int("attempt") ?? 0 }.first ?? 0) + 1
        let delay = min(3600.0, 30.0 * pow(2.0, Double(attempt - 1)))
        let final = attempt >= maxAttempts
        try db.execute("UPDATE sync_log SET attempt = ?, error = ?, state = ?, next_at = ? WHERE id = ?",
                       [.int(attempt), .text(error), .text(final ? "failed" : "pending"), .double(now().timeIntervalSince1970 + delay), .int(id)])
    }

    func retryFailed() throws {
        try db.execute("UPDATE sync_log SET state = 'pending', attempt = 0, next_at = 0 WHERE state = 'failed'")
    }

    func retrySync(_ id: Int) throws {
        try db.execute("UPDATE sync_log SET state = 'pending', attempt = 0, next_at = 0 WHERE id = ?", [.int(id)])
    }

    /// Logs a pull (issues read from GitHub) in the same table, so the Log screen shows both directions.
    func logPull(summary: String, ok: Bool, error: String? = nil) throws {
        try db.execute("INSERT INTO sync_log(ticket_id, op, payload, direction, state, attempt, next_at, error, at, done_at) VALUES(NULL,?,?,?,?,?,?,?,?,?)",
                       [.text("pull"), .text(JSONValue.object(["summary": .string(summary)]).jsonString()), "pull", .text(ok ? "done" : "failed"), 0, 0, .opt(error), .date(now()), .date(now())])
    }
}
