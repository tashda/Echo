import Foundation

/// The six kinds of ticket (decision A1).
public enum TicketType: String, CaseIterable, Codable, Sendable {
    case question, sketch, proposal, tweak, bug, theme

    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    public var label: String { "type:\(rawValue)" }
}

/// The sixteen statuses (decision A4). Raw values are the GitHub label suffixes (`status:your-call`).
public enum Status: String, CaseIterable, Codable, Sendable {
    case draft
    case checking
    case needsAnswers = "needs-answers"
    case ready
    case preparing
    case yourCall = "your-call"
    case revising
    case accepted
    case building
    case toVerify = "to-verify"
    case fixing
    case merged
    case done
    case blocked
    case parked
    case dropped

    public var label: String { "status:\(rawValue)" }

    public var displayName: String {
        switch self {
        case .draft: "Draft"
        case .checking: "Checking"
        case .needsAnswers: "Needs answers"
        case .ready: "Ready"
        case .preparing: "Preparing"
        case .yourCall: "Your call"
        case .revising: "Revising"
        case .accepted: "Accepted"
        case .building: "Building"
        case .toVerify: "To verify"
        case .fixing: "Fixing"
        case .merged: "Merged"
        case .done: "Done"
        case .blocked: "Blocked"
        case .parked: "Parked"
        case .dropped: "Dropped"
        }
    }

    /// Whose turn it is (decision A5).
    public var turn: Turn {
        switch self {
        case .draft, .needsAnswers, .yourCall, .toVerify: .you
        case .checking, .preparing, .revising, .building, .fixing: .agent
        case .ready, .accepted, .merged, .blocked: .hatch
        case .done: .finished
        case .parked, .dropped: .paused
        }
    }

    public var phase: Phase {
        switch self {
        case .draft, .checking, .needsAnswers, .ready: .intake
        case .preparing, .yourCall, .revising: .exploring
        case .accepted, .building, .toVerify, .fixing: .building
        case .merged, .done: .landed
        case .blocked, .parked, .dropped: .off
        }
    }

    /// No further work happens from here (a ticket can still be reopened by the owner).
    public var isTerminal: Bool { self == .done || self == .dropped }
    public var isActiveWork: Bool { !isTerminal && self != .parked }
}

public enum Turn: String, Codable, Sendable { case you, agent, hatch, finished, paused }

public enum Phase: String, CaseIterable, Codable, Sendable {
    case intake, exploring, building, landed, off
    public var displayName: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
}

/// Who is performing a move. The rules say who may do what, so the app (not an agent's memory) enforces them.
public enum Actor: String, Codable, Sendable { case owner, agent, hatch }

public struct Move: Hashable, Sendable {
    public let from: Status
    public let to: Status
}

public enum WorkflowError: Error, CustomStringConvertible, Equatable {
    case notAllowed(type: TicketType, from: Status, to: Status, actor: Actor)
    case ticketTypeCannot(String)

    public var description: String {
        switch self {
        case .notAllowed(let type, let from, let to, let actor):
            return "\(actor.rawValue) cannot move a \(type.rawValue) from \(from.displayName) to \(to.displayName)"
        case .ticketTypeCannot(let m): return m
        }
    }
}

/// The transition table. One place, tested, and the only way a status changes.
public enum Workflow {
    private struct Rule {
        let from: Status
        let to: Status
        let actors: Set<Actor>
        let types: Set<TicketType>
    }

    private static let all = Set(TicketType.allCases)
    private static let pipeline: Set<TicketType> = [.question, .sketch, .proposal, .tweak, .bug]
    private static let explore: Set<TicketType> = [.question, .sketch, .proposal]
    private static let build: Set<TicketType> = [.proposal, .tweak, .bug]
    private static let buildFirst: Set<TicketType> = [.tweak, .bug]

    private static let rules: [Rule] = {
        var r: [Rule] = []
        func add(_ from: Status, _ to: Status, _ actors: Set<Actor>, _ types: Set<TicketType>) {
            r.append(Rule(from: from, to: to, actors: actors, types: types))
        }
        // Intake
        add(.draft, .checking, [.owner, .hatch], pipeline)
        add(.draft, .done, [.hatch, .owner], [.theme])
        add(.checking, .needsAnswers, [.agent, .hatch], pipeline)
        add(.checking, .ready, [.agent, .hatch], pipeline)
        add(.needsAnswers, .ready, [.hatch], pipeline)
        add(.needsAnswers, .checking, [.owner, .hatch], pipeline)
        add(.ready, .preparing, [.agent, .hatch], explore)
        add(.ready, .building, [.agent, .hatch], buildFirst)
        // Exploring
        add(.preparing, .yourCall, [.agent, .hatch], explore)
        add(.preparing, .needsAnswers, [.agent, .hatch], explore)
        add(.yourCall, .revising, [.owner], [.sketch, .proposal])
        add(.yourCall, .accepted, [.owner], [.proposal])
        add(.yourCall, .done, [.owner, .hatch], [.question, .sketch])
        add(.revising, .yourCall, [.agent, .hatch], [.sketch, .proposal])
        add(.revising, .needsAnswers, [.agent, .hatch], [.sketch, .proposal])
        // Building
        add(.accepted, .building, [.agent, .hatch], [.proposal])
        add(.building, .toVerify, [.hatch], build)
        add(.building, .needsAnswers, [.agent, .hatch], build)
        add(.toVerify, .fixing, [.owner], build)
        add(.toVerify, .merged, [.hatch], build)
        add(.fixing, .toVerify, [.hatch], build)
        add(.fixing, .needsAnswers, [.agent, .hatch], build)
        // Landed
        add(.merged, .done, [.hatch], build)
        // Done can be reopened by the owner for another pass
        add(.done, .draft, [.owner], all)
        add(.dropped, .draft, [.owner], all)
        // Anywhere that is not finished: park, drop (owner) and block (Hatch)
        for status in Status.allCases where !status.isTerminal && status != .parked && status != .blocked {
            add(status, .parked, [.owner], all)
            add(status, .dropped, [.owner], all)
            add(status, .blocked, [.hatch], all)
        }
        add(.blocked, .parked, [.owner], all)
        add(.blocked, .dropped, [.owner], all)
        add(.parked, .dropped, [.owner], all)
        return r
    }()

    /// Where a Blocked or Parked ticket returns to is stored with the ticket, so these are allowed to any resumable status.
    public static func canResume(_ type: TicketType, to status: Status, from current: Status, actor: Actor) -> Bool {
        guard current == .blocked || current == .parked else { return false }
        guard status != .blocked, status != .parked, status != .dropped, status != .done else { return false }
        let allowedActor: Actor = current == .blocked ? .hatch : .owner
        return actor == allowedActor && rules.contains { $0.to == status && $0.types.contains(type) }
    }

    public static func isAllowed(type: TicketType, from: Status, to: Status, actor: Actor) -> Bool {
        if canResume(type, to: to, from: from, actor: actor) { return true }
        return rules.contains { $0.from == from && $0.to == to && $0.actors.contains(actor) && $0.types.contains(type) }
    }

    public static func validate(type: TicketType, from: Status, to: Status, actor: Actor) throws {
        guard isAllowed(type: type, from: from, to: to, actor: actor) else {
            throw WorkflowError.notAllowed(type: type, from: from, to: to, actor: actor)
        }
    }

    /// The statuses a ticket of this type can go to next, for the given actor.
    public static func nextStatuses(type: TicketType, from: Status, actor: Actor) -> [Status] {
        Status.allCases.filter { isAllowed(type: type, from: from, to: $0, actor: actor) }
    }

    /// The normal path of a ticket type (decision section 3.2), used for the progress display and tests.
    public static func path(for type: TicketType) -> [Status] {
        switch type {
        case .question: [.draft, .checking, .needsAnswers, .ready, .preparing, .yourCall, .done]
        case .sketch: [.draft, .checking, .needsAnswers, .ready, .preparing, .yourCall, .revising, .done]
        case .proposal: [.draft, .checking, .needsAnswers, .ready, .preparing, .yourCall, .revising, .accepted, .building, .toVerify, .fixing, .merged, .done]
        case .tweak, .bug: [.draft, .checking, .needsAnswers, .ready, .building, .toVerify, .fixing, .merged, .done]
        case .theme: [.draft, .done]
        }
    }

    public static var moves: [Move] { rules.map { Move(from: $0.from, to: $0.to) } }
}
