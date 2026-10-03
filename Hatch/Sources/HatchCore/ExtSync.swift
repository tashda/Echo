import Foundation

/// Small additions the sync module needs. They write what GitHub told us without queueing it back to GitHub.
public extension HatchStore {
    /// Remembers which GitHub comment a note became, so the next pull does not import it again.
    func setGhCommentId(noteId: Int, commentId: Int) throws {
        try db.execute("UPDATE note SET gh_comment_id = ? WHERE id = ?", [.int(commentId), .int(noteId)])
    }

    func setGhUpdatedAt(ticketId: Int, _ stamp: String?) throws {
        try db.execute("UPDATE ticket SET gh_updated_at = ? WHERE id = ?", [.opt(stamp), .int(ticketId)])
    }

    /// Takes a title/body edit made on GitHub (decision M1: GitHub owns text). Nothing is queued, or the edit would bounce back.
    func applyRemoteText(ticketId: Int, title: String?, body: String?) throws {
        guard let t = try ticket(id: ticketId) else { return }
        let newTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? t.title
        let newBody = body ?? t.body
        guard newTitle != t.title || newBody != t.body else { return }
        try db.transaction {
            try db.execute("UPDATE ticket SET title = ?, body = ?, updated_at = ? WHERE id = ?", [.text(newTitle), .text(newBody), .date(now()), .int(ticketId)])
            try indexTicket(ticketId)
            try record(ticketId, actor: "github", kind: "edit", payload: ["title": .bool(newTitle != t.title), "body": .bool(newBody != t.body), "source": "github"])
        }
    }

    /// Operations of a ticket that are still waiting (pending), whatever their backoff.
    func pendingOps(ticketId: Int) throws -> [SyncOp] {
        try syncLog(state: "pending", limit: 1000).filter { $0.ticketId == ticketId && $0.direction == "push" }
    }

    func hasGhComment(ticketId: Int, commentId: Int) throws -> Bool {
        try db.scalarInt("SELECT COUNT(*) FROM note WHERE ticket_id = ? AND gh_comment_id = ?", [.int(ticketId), .int(commentId)]) > 0
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
