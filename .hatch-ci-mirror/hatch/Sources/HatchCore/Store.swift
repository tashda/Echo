import Foundation

/// The single place that reads and writes Hatch's SQLite database. Every state change goes through here, so the
/// event log, the search index and the GitHub sync queue can never disagree with the ticket (decision: the app does the bookkeeping).
public final class HatchStore: @unchecked Sendable {
    public let db: Database
    public var now: @Sendable () -> Date

    public init(path: String, now: @escaping @Sendable () -> Date = { Date() }) throws {
        self.db = try Database(path: path)
        self.now = now
        try Schema.migrate(db)
    }

    public static func inMemory(now: @escaping @Sendable () -> Date = { Date() }) throws -> HatchStore {
        try HatchStore(path: ":memory:", now: now)
    }

    // MARK: Projects and repos

    @discardableResult
    public func upsertProject(key: String, name: String, config: ProjectConfig? = nil) throws -> Project {
        let json = try config.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) } ?? "{}"
        try db.transaction {
            if let existing = try project(key: key) {
                try db.execute("UPDATE project SET name = ?, config_json = ? WHERE id = ?", [.text(name), .text(config == nil ? (try configJSON(existing.id)) : json), .int(existing.id)])
            } else {
                try db.execute("INSERT INTO project(key, name, config_json, created_at) VALUES(?,?,?,?)",
                               [.text(key), .text(name), .text(json), .date(now())])
            }
            if let config, let p = try project(key: key) {
                for r in config.repos { try upsertRepo(projectId: p.id, repo: r) }
            }
        }
        return try project(key: key)!
    }

    private func configJSON(_ id: Int) throws -> String {
        try db.query("SELECT config_json FROM project WHERE id = ?", [.int(id)]) { $0.string("config_json") ?? "{}" }.first ?? "{}"
    }

    public func project(key: String) throws -> Project? {
        try db.query("SELECT * FROM project WHERE key = ?", [.text(key)], map: Self.project).first
    }

    public func project(id: Int) throws -> Project? {
        try db.query("SELECT * FROM project WHERE id = ?", [.int(id)], map: Self.project).first
    }

    public func projects() throws -> [Project] {
        try db.query("SELECT * FROM project ORDER BY name", map: Self.project)
    }

    private static func project(_ r: Row) throws -> Project {
        let config = r.string("config_json").flatMap { try? JSONDecoder().decode(ProjectConfig.self, from: Data($0.utf8)) }
        return Project(id: r.int("id")!, key: r.string("key")!, name: r.string("name")!, config: config, createdAt: r.date("created_at") ?? Date())
    }

    public func upsertRepo(projectId: Int, repo: RepoConfig) throws {
        let plans = String(decoding: try JSONEncoder().encode(repo.testPlans ?? []), as: UTF8.self)
        try db.execute("""
            INSERT INTO repo(project_id, role, remote, default_branch, local_path, build_cmd, test_plans_json)
            VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(project_id, role) DO UPDATE SET remote = excluded.remote, default_branch = excluded.default_branch,
                local_path = excluded.local_path, build_cmd = excluded.build_cmd, test_plans_json = excluded.test_plans_json
            """, [.int(projectId), .text(repo.role.rawValue), .text(repo.remote), .text(repo.branch),
                  .opt(repo.localPath), .opt(repo.buildCommand), .text(plans)])
    }

    public func repos(projectId: Int) throws -> [Repo] {
        try db.query("SELECT * FROM repo WHERE project_id = ? ORDER BY role", [.int(projectId)]) { r in
            Repo(id: r.int("id")!, projectId: r.int("project_id")!, role: RepoRole(rawValue: r.string("role")!) ?? .app,
                 remote: r.string("remote")!, defaultBranch: r.string("default_branch")!, localPath: r.string("local_path"),
                 buildCommand: r.string("build_cmd"),
                 testPlans: (try? JSONDecoder().decode([String].self, from: Data((r.string("test_plans_json") ?? "[]").utf8))) ?? [])
        }
    }

    public func repo(projectId: Int, role: RepoRole) throws -> Repo? {
        try repos(projectId: projectId).first { $0.role == role }
    }

    // MARK: Tickets

    static func ticket(_ r: Row) -> Ticket {
        Ticket(id: r.int("id")!, ghNumber: r.int("gh_number"), projectId: r.int("project_id")!,
               type: TicketType(rawValue: r.string("type")!) ?? .question,
               status: Status(rawValue: r.string("status")!) ?? .draft,
               prevStatus: r.string("prev_status").flatMap(Status.init(rawValue:)),
               turn: Turn(rawValue: r.string("turn")!) ?? .you,
               title: r.string("title")!, body: r.string("body") ?? "",
               originalTitle: r.string("original_title"), originalBody: r.string("original_body"),
               parentId: r.int("parent_id"), priority: r.int("priority") ?? 0, area: r.string("area"),
               revision: r.int("revision") ?? 1, takenBy: r.string("taken_by"),
               createdAt: r.date("created_at") ?? Date(), updatedAt: r.date("updated_at") ?? Date())
    }

    @discardableResult
    public func createTicket(projectId: Int, type: TicketType, title: String, body: String = "", area: String? = nil,
                             parentId: Int? = nil, ghNumber: Int? = nil, status: Status = .draft, actor: Actor = .owner) throws -> Ticket {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw StoreError.invalid("A ticket needs a title.") }
        let t = now()
        return try db.transaction {
            try db.execute("""
                INSERT INTO ticket(gh_number, project_id, type, status, turn, title, body, original_title, original_body, parent_id, area, created_at, updated_at)
                VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
                """, [.opt(ghNumber), .int(projectId), .text(type.rawValue), .text(status.rawValue), .text(status.turn.rawValue),
                      .text(trimmed), .text(body), .text(trimmed), .text(body), .opt(parentId), .opt(area), .date(t), .date(t)])
            let id = Int(db.lastInsertRowID)
            try indexTicket(id)
            try record(id, actor: actor.rawValue, kind: "created", payload: ["type": .string(type.rawValue), "status": .string(status.rawValue)])
            if let parentId { try link(from: id, to: parentId, kind: .parent) }
            if status != .draft && ghNumber == nil { try enqueueCreateIssue(id) }
            return try ticket(id: id)!
        }
    }

    public func ticket(id: Int) throws -> Ticket? {
        try db.query("SELECT * FROM ticket WHERE id = ?", [.int(id)]) { Self.ticket($0) }.first
    }

    public func ticket(ghNumber: Int, projectId: Int? = nil) throws -> Ticket? {
        try db.query("SELECT * FROM ticket WHERE gh_number = ?", [.int(ghNumber)]) { Self.ticket($0) }.first
    }

    /// Accepts `#151`, `151`, `new-12` and `L12`.
    public func resolve(_ ref: String) throws -> Ticket {
        let s = ref.trimmingCharacters(in: .whitespaces)
        var found: Ticket?
        if s.lowercased().hasPrefix("new-"), let n = Int(s.dropFirst(4)) { found = try ticket(id: n) }
        else if s.hasPrefix("L"), let n = Int(s.dropFirst()) { found = try ticket(id: n) }
        else if let n = Int(s.hasPrefix("#") ? String(s.dropFirst()) : s) { found = try ticket(ghNumber: n) }
        guard let found else { throw StoreError.notFound("ticket \(ref)") }
        return found
    }

    public func tickets(_ f: TicketFilter = TicketFilter()) throws -> [Ticket] {
        var clauses: [String] = [], params: [SQLValue] = []
        var from = "ticket t"
        if let p = f.projectId { clauses.append("t.project_id = ?"); params.append(.int(p)) }
        if let s = f.statuses, !s.isEmpty { clauses.append("t.status IN (\(s.map { _ in "?" }.joined(separator: ",")))"); params += s.map { .text($0.rawValue) } }
        if let ty = f.types, !ty.isEmpty { clauses.append("t.type IN (\(ty.map { _ in "?" }.joined(separator: ",")))"); params += ty.map { .text($0.rawValue) } }
        if let turn = f.turn { clauses.append("t.turn = ?"); params.append(.text(turn.rawValue)) }
        if let pid = f.parentId { clauses.append("t.parent_id = ?"); params.append(.int(pid)) }
        if let a = f.area { clauses.append("t.area = ?"); params.append(.text(a)) }
        var order = "t.updated_at DESC"
        if let text = f.text, let q = Self.ftsQuery(text) {
            from = "ticket t JOIN ticket_fts ON ticket_fts.ticket_id = t.id"
            clauses.append("ticket_fts MATCH ?"); params.append(.text(q))
            order = "bm25(ticket_fts)"
        }
        let whereSQL = clauses.isEmpty ? "" : " WHERE " + clauses.joined(separator: " AND ")
        let limit = f.limit.map { " LIMIT \($0)" } ?? ""
        return try db.query("SELECT t.* FROM \(from)\(whereSQL) ORDER BY \(order)\(limit)", params) { Self.ticket($0) }
    }

    /// Moves a ticket to a new status. The only way a status changes: validated by `Workflow`, logged, indexed and queued for GitHub.
    @discardableResult
    public func move(_ id: Int, to newStatus: Status, actor: Actor, reason: String? = nil) throws -> Ticket {
        try db.transaction {
            guard var t = try ticket(id: id) else { throw StoreError.notFound("ticket \(id)") }
            let from = t.status
            if from == newStatus { return t }
            try Workflow.validate(type: t.type, from: from, to: newStatus, actor: actor)
            var prev: Status? = nil
            if newStatus == .blocked || newStatus == .parked { prev = from == .blocked || from == .parked ? t.prevStatus : from }
            let takenBy: SQLValue = (newStatus == .ready || newStatus == .yourCall || newStatus == .toVerify || newStatus == .draft || newStatus.isTerminal) ? .null : .opt(t.takenBy)
            try db.execute("UPDATE ticket SET status = ?, prev_status = ?, turn = ?, taken_by = ?, updated_at = ? WHERE id = ?",
                           [.text(newStatus.rawValue), .opt(prev?.rawValue), .text(newStatus.turn.rawValue), takenBy, .date(now()), .int(id)])
            try record(id, actor: actor.rawValue, kind: "status", payload: ["from": .string(from.rawValue), "to": .string(newStatus.rawValue), "reason": reason.map { .string($0) } ?? .null])
            if from == .draft { try enqueueCreateIssue(id) } else { try enqueueLabels(id) }
            if newStatus == .done { try enqueueClose(id, reason: "completed") }
            if newStatus == .dropped { try enqueueClose(id, reason: "not_planned") }
            if from.isTerminal && !newStatus.isTerminal { try enqueue(op: "issue.reopen", ticketId: id, payload: [:]) }
            if newStatus.isTerminal || newStatus == .parked { try releaseClaims(ticketId: id) }
            t = try ticket(id: id)!
            if let parent = t.parentId, newStatus == .done { try completeThemeIfFinished(parent) }
            return t
        }
    }

    /// Brings a Blocked or Parked ticket back to the status it had.
    @discardableResult
    public func resume(_ id: Int, actor: Actor) throws -> Ticket {
        guard let t = try ticket(id: id), t.status == .blocked || t.status == .parked, let prev = t.prevStatus else {
            throw StoreError.invalid("Only a Blocked or Parked ticket can be resumed.")
        }
        return try move(id, to: prev, actor: actor, reason: "resumed")
    }

    /// Changes the ticket type while it is still in intake (decision E9). The owner decides; the vetting agent only suggests.
    @discardableResult
    public func changeType(_ id: Int, to type: TicketType, actor: Actor, reason: String? = nil) throws -> Ticket {
        try db.transaction {
            guard let t = try ticket(id: id) else { throw StoreError.notFound("ticket \(id)") }
            guard [.draft, .checking, .needsAnswers, .ready].contains(t.status) else {
                throw StoreError.invalid("The type can only change before work starts (it is \(t.status.displayName)).")
            }
            guard actor == .owner || actor == .hatch else { throw StoreError.invalid("Only the owner changes a ticket's type.") }
            if t.type == type { return t }
            try db.execute("UPDATE ticket SET type = ?, updated_at = ? WHERE id = ?", [.text(type.rawValue), .date(now()), .int(id)])
            try record(id, actor: actor.rawValue, kind: "type", payload: ["from": .string(t.type.rawValue), "to": .string(type.rawValue), "reason": reason.map { .string($0) } ?? .null])
            if t.status != .draft { try enqueueLabels(id) }
            return try ticket(id: id)!
        }
    }

    /// Edits the text. The first edit keeps what the owner originally wrote (decision E8: the original is always kept).
    @discardableResult
    public func update(_ id: Int, title: String? = nil, body: String? = nil, actor: Actor, area: String?? = nil, priority: Int? = nil) throws -> Ticket {
        try db.transaction {
            guard let t = try ticket(id: id) else { throw StoreError.notFound("ticket \(id)") }
            let newTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? t.title
            guard !newTitle.isEmpty else { throw StoreError.invalid("A ticket needs a title.") }
            let newBody = body ?? t.body
            let newArea: String? = area ?? t.area
            try db.execute("UPDATE ticket SET title = ?, body = ?, area = ?, priority = ?, updated_at = ? WHERE id = ?",
                           [.text(newTitle), .text(newBody), .opt(newArea), .int(priority ?? t.priority), .date(now()), .int(id)])
            if newTitle != t.title || newBody != t.body {
                try record(id, actor: actor.rawValue, kind: "edit", payload: ["title": .bool(newTitle != t.title), "body": .bool(newBody != t.body)])
                try indexTicket(id)
                if t.status != .draft { try enqueueUpdate(id, title: newTitle != t.title ? newTitle : nil, body: newBody != t.body ? newBody : nil) }
            }
            if newArea != t.area, t.status != .draft { try enqueueLabels(id) }
            return try ticket(id: id)!
        }
    }

    public func setTakenBy(_ id: Int, _ who: String?) throws {
        try db.execute("UPDATE ticket SET taken_by = ?, updated_at = ? WHERE id = ?", [.opt(who), .date(now()), .int(id)])
    }

    public func bumpRevision(_ id: Int) throws -> Int {
        try db.execute("UPDATE ticket SET revision = revision + 1, updated_at = ? WHERE id = ?", [.date(now()), .int(id)])
        return try ticket(id: id)?.revision ?? 1
    }

    // MARK: Themes

    public func themeProgress(_ id: Int) throws -> (done: Int, total: Int) {
        let rows = try db.query("SELECT status FROM ticket WHERE parent_id = ? AND status != 'dropped'", [.int(id)]) { $0.string("status") ?? "" }
        return (rows.filter { $0 == Status.done.rawValue }.count, rows.count)
    }

    private func completeThemeIfFinished(_ id: Int) throws {
        guard let theme = try ticket(id: id), theme.type == .theme, theme.status != .done else { return }
        let p = try themeProgress(id)
        if p.total > 0 && p.done == p.total {
            try db.execute("UPDATE ticket SET status = 'done', turn = 'finished', updated_at = ? WHERE id = ?", [.date(now()), .int(id)])
            try record(id, actor: "hatch", kind: "status", payload: ["from": .string(theme.status.rawValue), "to": "done", "reason": "all child tickets are done"])
            try enqueueLabels(id)
            try enqueueClose(id, reason: "completed")
        }
    }

    // MARK: Counting for the Desk and sidebar

    public func countByTurn(projectId: Int? = nil) throws -> [Turn: Int] {
        var sql = "SELECT turn, COUNT(*) AS n FROM ticket"
        var params: [SQLValue] = []
        if let projectId { sql += " WHERE project_id = ?"; params.append(.int(projectId)) }
        sql += " GROUP BY turn"
        var out: [Turn: Int] = [:]
        for (turn, n) in try db.query(sql, params, map: { ($0.string("turn")!, $0.int("n")!) }) { if let t = Turn(rawValue: turn) { out[t] = n } }
        return out
    }

    /// Tickets that wait for the owner, grouped the way the Desk shows them (decision C2).
    public func deskQueue(projectId: Int? = nil) throws -> [(status: Status, tickets: [Ticket])] {
        let order: [Status] = [.yourCall, .needsAnswers, .toVerify, .draft]
        var out: [(Status, [Ticket])] = []
        for s in order {
            let ts = try tickets(TicketFilter(projectId: projectId, statuses: [s], turn: .you))
            if !ts.isEmpty { out.append((s, ts.sorted { $0.updatedAt < $1.updatedAt })) }
        }
        return out
    }

    // MARK: Settings

    public func setting(_ key: String) throws -> String? {
        try db.query("SELECT value FROM setting WHERE key = ?", [.text(key)]) { $0.string("value") }.first ?? nil
    }

    public func setSetting(_ key: String, _ value: String) throws {
        try db.execute("INSERT INTO setting(key, value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value = excluded.value", [.text(key), .text(value)])
    }
}
