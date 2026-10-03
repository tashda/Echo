import Foundation
import HatchCore

public struct IrisOutcome: Equatable, Sendable {
    public var questionsAsked: Int
    public var suggestionStored: Bool
    /// The ticket's status after Iris's result was applied.
    public var status: Status
}

/// Turns Iris's answer into store changes, under the owner's rules: questions go to the owner, a rewrite or a type change
/// is only a pending suggestion (E8, E9), and nothing about the ticket's text or type changes until the owner decides.
public enum IrisApplier {
    public static let name = "Iris"

    @discardableResult
    public static func apply(_ result: VettingResult, to ticketId: Int, store: HatchStore) throws -> IrisOutcome {
        try store.db.transaction {
            guard let t = try store.ticket(id: ticketId) else { throw StoreError.notFound("ticket \(ticketId)") }
            guard t.status == .checking else {
                throw StoreError.invalid("\(t.displayNumber) is \(t.status.displayName), not Checking, so Iris's answer was not applied.")
            }
            // The first question moves the ticket to Needs answers, by the agent.
            for q in result.questions { try store.ask(ticketId, text: q.text, suggestions: q.suggestions, by: name, actor: .agent) }

            var suggestion = VettingSuggestion()
            if let r = result.rewrite {
                let title = r.title.isEmpty ? t.title : r.title
                let body = r.body.isEmpty ? t.body : r.body
                if title != t.title || body != t.body { suggestion.rewrite = .init(title: title, body: body, changes: r.changes) }
            }
            if let ts = result.typeSuggestion, ts.type != t.type { suggestion.typeSuggestion = .init(type: ts.type, reason: ts.reason) }
            if let ref = result.duplicateOf, let dup = try? store.resolve(ref), dup.id != t.id { suggestion.duplicateOf = dup.id }
            suggestion.related = try result.related.compactMap { (try? store.resolve($0))?.id }.filter { $0 != t.id }
            suggestion.specTouches = result.specTouches

            let stored = !suggestion.isEmpty
            if stored { try store.recordSuggestion(ticketId: ticketId, suggestion, by: name) }

            let status: Status
            if !result.questions.isEmpty {
                status = .needsAnswers
            } else if stored {
                // Nothing to answer, but the owner must look at the suggestion before work starts.
                status = try store.move(ticketId, to: .needsAnswers, actor: .agent, reason: "\(name) has a suggestion").status
            } else {
                status = try store.move(ticketId, to: .ready, actor: .hatch, reason: "\(name) found nothing to ask").status
            }
            return IrisOutcome(questionsAsked: result.questions.count, suggestionStored: stored, status: status)
        }
    }

    // MARK: The owner's decision

    /// Accept: the rewrite becomes the ticket text (the original stays in `originalTitle` and `originalBody`).
    /// The type changes only when `applyType` is true, and a duplicate link is created only when `linkDuplicate` is true.
    @discardableResult
    public static func accept(ticketId: Int, store: HatchStore, applyType: Bool = false, linkDuplicate: Bool = false) throws -> Ticket {
        let s = try pending(ticketId, store)
        return try resolve(ticketId, store, s, choice: "accept", title: s.rewrite?.title, body: s.rewrite?.body, actor: .agent, applyType: applyType, linkDuplicate: linkDuplicate)
    }

    /// Edit: the owner's own version of the rewrite becomes the ticket text.
    @discardableResult
    public static func edit(ticketId: Int, title: String, body: String, store: HatchStore, applyType: Bool = false, linkDuplicate: Bool = false) throws -> Ticket {
        let s = try pending(ticketId, store)
        return try resolve(ticketId, store, s, choice: "edit", title: title, body: body, actor: .owner, applyType: applyType, linkDuplicate: linkDuplicate)
    }

    /// Keep mine: the text stays as written. The type and duplicate choices are still the owner's.
    @discardableResult
    public static func keepMine(ticketId: Int, store: HatchStore, applyType: Bool = false, linkDuplicate: Bool = false) throws -> Ticket {
        let s = try pending(ticketId, store)
        return try resolve(ticketId, store, s, choice: "keep", title: nil, body: nil, actor: .owner, applyType: applyType, linkDuplicate: linkDuplicate)
    }

    private static func pending(_ id: Int, _ store: HatchStore) throws -> VettingSuggestion {
        guard let s = try store.pendingSuggestion(ticketId: id) else { throw StoreError.invalid("There is no pending suggestion from \(name) on this ticket.") }
        return s
    }

    private static func resolve(_ id: Int, _ store: HatchStore, _ s: VettingSuggestion, choice: String, title: String?, body: String?,
                                actor: Actor, applyType: Bool, linkDuplicate: Bool) throws -> Ticket {
        try store.db.transaction {
            if title != nil || body != nil { try store.update(id, title: title, body: body, actor: actor) }
            var typeChanged = false
            if applyType, let ts = s.typeSuggestion {
                try store.changeType(id, to: ts.type, actor: .owner, reason: ts.reason); typeChanged = true
            }
            var linked = false
            if linkDuplicate, let dup = s.duplicateOf { try store.link(from: id, to: dup, kind: .duplicates); linked = true }
            try store.resolveSuggestion(ticketId: id, choice: choice, typeChanged: typeChanged, duplicateLinked: linked)
            // With nothing left to answer the ticket is ready; questions still open keep it in Needs answers.
            let t = try store.ticket(id: id)!
            if t.status == .needsAnswers, try store.questions(ticketId: id, openOnly: true).isEmpty {
                return try store.move(id, to: .ready, actor: .hatch, reason: "suggestion decided")
            }
            return t
        }
    }
}
