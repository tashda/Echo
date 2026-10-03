import Foundation

public enum AgentTaskKind: String, Codable, Sendable { case vet, prepare, build, revise, fix }

public struct AgentTask: Equatable, Sendable {
    public let ticket: Ticket
    public let kind: AgentTaskKind
}

/// What an agent may do next, decided by the app so agents never have to remember the procedure (`hatch next` and `hatch take`).
public extension HatchStore {
    func activeAgentCount() throws -> Int {
        try db.scalarInt("SELECT COUNT(*) FROM ticket WHERE taken_by IS NOT NULL AND turn = 'agent'")
    }

    func maxAgents(projectId: Int? = nil) throws -> Int {
        // A value set in the app (Settings) wins over the project's file, which wins over the default of 3.
        if let s = try setting("max_agents"), let n = Int(s) { return n }
        if let projectId, let p = try project(id: projectId), let c = p.config { return c.maxAgents }
        return 3
    }

    static func taskKind(for status: Status, type: TicketType) -> AgentTaskKind? {
        switch status {
        case .checking: .vet
        case .ready: type == .tweak || type == .bug ? .build : .prepare
        case .accepted: .build
        case .revising: .revise
        case .fixing: .fix
        default: nil
        }
    }

    /// Work waiting for an agent, highest priority and oldest first. Honors the agent limit.
    func agentWork(projectId: Int? = nil) throws -> [AgentTask] {
        var sql = "SELECT * FROM ticket WHERE taken_by IS NULL AND status IN ('checking','ready','accepted','revising','fixing')"
        var params: [SQLValue] = []
        if let projectId { sql += " AND project_id = ?"; params.append(.int(projectId)) }
        sql += " ORDER BY priority DESC, updated_at ASC"
        let tickets = try db.query(sql, params) { HatchStore.ticket($0) }
        return tickets.compactMap { t in Self.taskKind(for: t.status, type: t.type).map { AgentTask(ticket: t, kind: $0) } }
    }

    /// Vetting is cheap and does not use a build slot; preparing and building do.
    func takeSlotAvailable(kind: AgentTaskKind, projectId: Int?) throws -> Bool {
        if kind == .vet { return true }
        return try activeAgentCount() < maxAgents(projectId: projectId)
    }

    /// An agent claims a ticket. Moves it into its working status (Preparing or Building) where the workflow says so.
    @discardableResult
    func take(_ ticketId: Int, agent: String) throws -> AgentTask {
        try db.transaction {
            guard let t = try ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            if let who = t.takenBy { throw StoreError.invalid("\(t.displayNumber) is already taken by \(who).") }
            guard let kind = Self.taskKind(for: t.status, type: t.type) else {
                throw StoreError.invalid("\(t.displayNumber) is \(t.status.displayName); there is nothing for an agent to do.")
            }
            guard try takeSlotAvailable(kind: kind, projectId: t.projectId) else {
                throw StoreError.invalid("All agent slots are in use (\(try maxAgents(projectId: t.projectId))).")
            }
            if kind == .build, try !openBlockers(ticketId: ticketId).isEmpty {
                throw StoreError.invalid("\(t.displayNumber) is blocked by an open ticket.")
            }
            var current = t
            switch (t.status, kind) {
            case (.ready, .prepare): current = try move(ticketId, to: .preparing, actor: .agent, reason: "taken by \(agent)")
            case (.ready, .build), (.accepted, .build): current = try move(ticketId, to: .building, actor: .agent, reason: "taken by \(agent)")
            default: break
            }
            try setTakenBy(ticketId, agent)
            try record(ticketId, actor: agent, kind: "take", payload: ["task": .string(kind.rawValue)])
            return AgentTask(ticket: try ticket(id: current.id)!, kind: kind)
        }
    }

    /// Gives a ticket back without finishing (an agent that stops, or the owner pressing Stop).
    func release(_ ticketId: Int, reason: String) throws {
        try setTakenBy(ticketId, nil)
        try record(ticketId, actor: "hatch", kind: "release", payload: ["reason": .string(reason)])
    }
}
