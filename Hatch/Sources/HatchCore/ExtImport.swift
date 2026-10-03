import Foundation

// Additive helpers for HatchImport. Nothing here changes existing core behaviour.

public extension HatchStore {
    /// Adds a history event with its original time. `record` always stamps "now", which would put imported history in the wrong order.
    func recordEvent(_ ticketId: Int, actor: String, kind: String, payload: JSONValue = [:], at: Date) throws {
        try db.execute("INSERT INTO event(ticket_id, at, actor, kind, payload) VALUES(?,?,?,?,?)",
                       [.int(ticketId), .date(at), .text(actor), .text(kind), .text(payload.jsonString())])
    }

    /// Writes a historical status straight onto a ticket, skipping `Workflow.validate` and the GitHub queue.
    /// Why: an imported ticket (for example one that is already In Echo) arrives in its final state; walking it through the
    /// legal chain Draft, Checking, Ready, ... would invent events that never happened and queue a flood of label updates.
    /// The turn follows the status, as everywhere else. Callers decide whether to queue the ticket for GitHub afterwards.
    func setImportedState(_ id: Int, status: Status, createdAt: Date, updatedAt: Date, takenBy: String? = nil) throws {
        guard try ticket(id: id) != nil else { throw StoreError.notFound("ticket \(id)") }
        try db.execute("UPDATE ticket SET status = ?, prev_status = NULL, turn = ?, taken_by = ?, created_at = ?, updated_at = ? WHERE id = ?",
                       [.text(status.rawValue), .text(status.turn.rawValue), .opt(takenBy), .date(createdAt), .date(updatedAt), .int(id)])
    }

    /// Ids of tickets of a project whose body contains `needle`. The caller checks the exact match; this is only the cheap filter.
    func ticketIds(projectId: Int, bodyContaining needle: String) throws -> [Int] {
        try db.query("SELECT id FROM ticket WHERE project_id = ? AND instr(body, ?) > 0 ORDER BY id", [.int(projectId), .text(needle)]) { $0.int("id")! }
    }

    /// Removes Spec items that came from files under `sourcePrefix` and whose code is no longer in `keeping`.
    /// Why: when a line disappears from a Spec file, the search index must forget it too. Items from other sources stay.
    @discardableResult
    func deleteSpecItems(projectId: Int, sourcePrefix: String, notIn keeping: Set<String>) throws -> [String] {
        try db.transaction {
            let rows = try db.query("SELECT id, code, source FROM spec_item WHERE project_id = ?", [.int(projectId)]) {
                (id: $0.int("id")!, code: $0.string("code")!, source: $0.string("source"))
            }
            var removed: [String] = []
            for r in rows where !keeping.contains(r.code) {
                guard let source = r.source, source.hasPrefix(sourcePrefix) else { continue }
                try db.execute("DELETE FROM spec_fts WHERE spec_id = ?", [.int(r.id)])
                try db.execute("DELETE FROM spec_item WHERE id = ?", [.int(r.id)])
                removed.append(r.code)
            }
            return removed.sorted()
        }
    }
}
