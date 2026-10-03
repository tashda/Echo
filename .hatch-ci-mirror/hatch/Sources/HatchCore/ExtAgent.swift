import Foundation

// Additive store functions for the agent module (Iris's pending suggestion). Nothing here changes a ticket by itself:
// a suggestion is an event, and only the owner's choice (Accept, Edit, Keep mine) touches the text or the type.

/// What Iris suggested and the owner has not yet decided (decisions E8, E9, E6).
public struct VettingSuggestion: Codable, Equatable, Sendable {
    public struct Rewrite: Codable, Equatable, Sendable {
        public var title: String
        public var body: String
        public var changes: [String]
        public init(title: String, body: String, changes: [String] = []) { self.title = title; self.body = body; self.changes = changes }
    }
    public struct TypeChange: Codable, Equatable, Sendable {
        public var type: TicketType
        public var reason: String
        public init(type: TicketType, reason: String) { self.type = type; self.reason = reason }
    }
    public var rewrite: Rewrite?
    public var typeSuggestion: TypeChange?
    /// Ticket id (not GitHub number) of the ticket this one probably duplicates.
    public var duplicateOf: Int?
    public var related: [Int]
    public var specTouches: [String]

    public init(rewrite: Rewrite? = nil, typeSuggestion: TypeChange? = nil, duplicateOf: Int? = nil, related: [Int] = [], specTouches: [String] = []) {
        self.rewrite = rewrite; self.typeSuggestion = typeSuggestion; self.duplicateOf = duplicateOf; self.related = related; self.specTouches = specTouches
    }

    public var isEmpty: Bool { rewrite == nil && typeSuggestion == nil && duplicateOf == nil }
}

public extension HatchStore {
    /// Stores a suggestion as a `vetting` event. The ticket is not changed.
    func recordSuggestion(ticketId: Int, _ suggestion: VettingSuggestion, by: String = "Iris") throws {
        let data = try JSONEncoder().encode(suggestion)
        try record(ticketId, actor: by, kind: "vetting", payload: JSONValue.parse(String(decoding: data, as: UTF8.self)))
    }

    /// The newest suggestion that the owner has not resolved yet.
    func pendingSuggestion(ticketId: Int) throws -> VettingSuggestion? {
        let events = try self.events(ticketId: ticketId, kinds: ["vetting", "vetting-resolved"])
        guard let last = events.last, last.kind == "vetting" else { return nil }
        return try? JSONDecoder().decode(VettingSuggestion.self, from: Data(last.payload.jsonString().utf8))
    }

    /// Marks the pending suggestion as decided. `choice` is accept, edit or keep.
    func resolveSuggestion(ticketId: Int, choice: String, typeChanged: Bool, duplicateLinked: Bool, actor: String = "owner") throws {
        try record(ticketId, actor: actor, kind: "vetting-resolved",
                   payload: ["choice": .string(choice), "typeChanged": .bool(typeChanged), "duplicateLinked": .bool(duplicateLinked)])
    }
}
