import SwiftUI
import HatchCore
import HatchAgent

/// Word-level comparison of two texts, drawn with colour, underline and strikethrough (decision E8).
enum WordDiff {
    static func marks(old: String, new: String) -> (removed: Set<Int>, inserted: Set<Int>) {
        let oldWords: [String] = old.components(separatedBy: " ")
        let newWords: [String] = new.components(separatedBy: " ")
        let diff = newWords.difference(from: oldWords)
        var removed = Set<Int>()
        var inserted = Set<Int>()
        for change in diff {
            switch change {
            case .remove(let offset, _, _): removed.insert(offset)
            case .insert(let offset, _, _): inserted.insert(offset)
            }
        }
        return (removed, inserted)
    }

    static func originalText(old: String, new: String) -> Text {
        let m = marks(old: old, new: new)
        let words: [String] = old.components(separatedBy: " ")
        var out = Text("")
        for (i, word) in words.enumerated() {
            let piece: String = i < words.count - 1 ? word + " " : word
            if m.removed.contains(i) {
                out = out + Text(piece).foregroundStyle(Theme.critical).strikethrough()
            } else {
                out = out + Text(piece)
            }
        }
        return out
    }

    static func suggestedText(old: String, new: String) -> Text {
        let m = marks(old: old, new: new)
        let words: [String] = new.components(separatedBy: " ")
        var out = Text("")
        for (i, word) in words.enumerated() {
            let piece: String = i < words.count - 1 ? word + " " : word
            if m.inserted.contains(i) {
                out = out + Text(piece).foregroundStyle(Theme.finished).underline()
            } else {
                out = out + Text(piece)
            }
        }
        return out
    }
}

/// The review after Iris has checked a ticket: answer cards, the rewrite as a diff, the type suggestion, a likely duplicate.
/// Used inside the composer after Submit and at the top of a ticket's Overview (decisions E4, E6, E8, E9).
/// Parts that are not the text (type, duplicate) are decided one at a time; the text decision (Accept, Edit, Keep mine)
/// resolves the whole suggestion through `IrisApplier`, and anything not yet decided stays as it is.
struct IrisReviewView: View {
    @EnvironmentObject var state: AppState
    let ticketId: Int
    var showIdleMessage: Bool = false

    @State private var ticket: Ticket?
    @State private var suggestion: VettingSuggestion?
    @State private var suggestionId: Int = 0
    @State private var decided: Set<String> = []
    @State private var openQuestionCount = 0
    @State private var failure: String?
    @State private var duplicateTicket: Ticket?
    @State private var editing = false
    @State private var editTitle = ""
    @State private var editBody = ""
    @State private var confirmMerge = false

    private var rewrite: VettingSuggestion.Rewrite? { suggestion?.rewrite }

    private func typePending(_ t: Ticket) -> TicketType? {
        guard let change = suggestion?.typeSuggestion, change.type != t.type, !decided.contains("type") else { return nil }
        return change.type
    }

    private var duplicatePending: Bool {
        suggestion?.duplicateOf != nil && duplicateTicket != nil && !decided.contains("duplicate")
    }

    private var hasAnything: Bool { suggestion != nil || openQuestionCount > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let ticket {
                content(ticket)
            }
        }
        .autoReload(every: 3) { load() }
        .sheet(isPresented: $editing) { editSheet }
        .confirmationDialog("Merge into the other ticket?", isPresented: $confirmMerge) {
            Button("Mark this as a duplicate and drop it", role: .destructive) { merge() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This ticket is linked as a duplicate and dropped. Nothing is deleted; you can reopen it later.")
        }
    }

    @ViewBuilder private func content(_ ticket: Ticket) -> some View {
        if ticket.status == .checking {
            checking(ticket)
        } else if hasAnything {
            header
            if duplicatePending { duplicateCard }
            if let newType = typePending(ticket) { typeCard(ticket, newType) }
            if openQuestionCount > 0 { AnswerCardsView(ticketId: ticketId) }
            if let rewrite { rewriteCard(ticket, rewrite) }
            alsoFound
        } else if showIdleMessage {
            idle(ticket)
        }
    }

    // MARK: Parts

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles").foregroundStyle(Theme.agent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Iris checked this ticket")
                    .font(.subheadline.weight(.semibold))
                Text(headerDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerDetail: String {
        var parts: [String] = []
        if openQuestionCount > 0 { parts.append(Format.count(openQuestionCount, "question") + " for you") }
        if rewrite != nil { parts.append("a suggested rewrite") }
        if suggestion?.typeSuggestion != nil { parts.append("a type suggestion") }
        if suggestion?.duplicateOf != nil { parts.append("a likely duplicate") }
        return parts.isEmpty ? "Nothing needs your attention." : parts.joined(separator: ", ").capitalizedFirst
    }

    private func checking(_ ticket: Ticket) -> some View {
        let slow = Date().timeIntervalSince(ticket.updatedAt) > 120
        return HStack(spacing: 10) {
            if failure == nil { ProgressView().controlSize(.small) }
            VStack(alignment: .leading, spacing: 2) {
                Text(failure == nil ? "Iris is checking this ticket" : "Iris could not finish the check")
                    .font(.subheadline.weight(.semibold))
                Text(checkingDetail(slow: slow))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if failure != nil || slow {
                Button("Check again") { VettingBridge.start(ticketId: ticket.id, state: state) }
            }
        }
        .padding(12)
        .background(failure == nil ? Theme.agentBackground : Theme.criticalBackground, in: RoundedRectangle(cornerRadius: 8))
    }

    private func checkingDetail(slow: Bool) -> String {
        if let failure { return failure }
        if slow { return "This is taking longer than usual." }
        return "Iris compares it with other tickets and the Spec, then asks questions before any work starts."
    }

    private func idle(_ ticket: Ticket) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle").foregroundStyle(Theme.finished)
            Text(ticket.status == .ready ? "Iris had nothing to ask. The ticket is Ready." : "Nothing to review.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var duplicateCard: some View {
        if let other = duplicateTicket {
            SectionCard("Likely duplicate") {
                HStack(spacing: 8) {
                    Button {
                        state.open(other)
                    } label: {
                        HStack(spacing: 6) {
                            Text(other.displayNumber).foregroundStyle(.secondary)
                            Text(other.title)
                        }
                    }
                    .buttonStyle(.link)
                    StatusChip(status: other.status)
                }
                Text("Link keeps both tickets and records the connection. Merge links them and drops this one. Keep separate leaves both alone.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Link") { linkDuplicate(other) }
                    Button("Merge") { confirmMerge = true }
                    Button("Keep separate") { record("duplicate", outcome: "kept") }
                }
                .controlSize(.small)
            }
        }
    }

    private func typeCard(_ ticket: Ticket, _ newType: TicketType) -> some View {
        SectionCard("Type") {
            HStack(spacing: 8) {
                TypeBadge(type: ticket.type)
                Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
                TypeBadge(type: newType)
            }
            if let reason = suggestion?.typeSuggestion?.reason, !reason.isEmpty {
                Text(reason).font(.callout).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Button("Accept") { acceptType(newType) }
                    .buttonStyle(.borderedProminent)
                Button("Keep mine") { record("type", outcome: "kept") }
            }
            .controlSize(.small)
        }
    }

    private func rewriteCard(_ ticket: Ticket, _ r: VettingSuggestion.Rewrite) -> some View {
        SectionCard("Suggested rewrite") {
            if r.title != ticket.title {
                diffColumns(old: ticket.title, new: r.title, bold: true)
            }
            if r.body != ticket.body {
                diffColumns(old: ticket.body, new: r.body, bold: false)
            }
            if !r.changes.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(r.changes, id: \.self) { change in
                        Text("\u{2022} \(change)").font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Removed words are struck through in red; added words are underlined in green. Your original text is always kept in the history. Type and duplicate choices you have not made stay as they are.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Accept") { decideText(.accept) }
                    .buttonStyle(.borderedProminent)
                Button("Edit") {
                    editTitle = r.title
                    editBody = r.body
                    editing = true
                }
                Button("Keep mine") { decideText(.keep) }
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder private var alsoFound: some View {
        if let s = suggestion, !s.related.isEmpty || !s.specTouches.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !s.related.isEmpty {
                    Text("Related: " + relatedText(s.related))
                }
                if !s.specTouches.isEmpty {
                    Text("Spec: " + s.specTouches.joined(separator: ", "))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func relatedText(_ ids: [Int]) -> String {
        let names: [String] = ids.compactMap { (try? state.store.ticket(id: $0))?.displayNumber }
        return names.joined(separator: ", ")
    }

    private func diffColumns(old: String, new: String, bold: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Yours").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                WordDiff.originalText(old: old, new: new)
                    .font(diffFont(bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Iris suggests").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                WordDiff.suggestedText(old: old, new: new)
                    .font(diffFont(bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func diffFont(_ bold: Bool) -> Font {
        if bold { return Font.body.weight(.semibold) }
        return Font.body
    }

    private var editSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit the suggestion")
                .font(.title3.weight(.semibold))
            TextField("Title", text: $editTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $editBody)
                .font(.body)
                .frame(minHeight: 200)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            HStack {
                Spacer()
                Button("Cancel") { editing = false }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    editing = false
                    decideText(.edit)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 560)
    }

    // MARK: Actions

    private enum TextChoice { case accept, edit, keep }

    private func decideText(_ choice: TextChoice) {
        let id = ticketId
        let store = state.store
        let title = editTitle
        let body = editBody
        // Anything the owner did not decide is recorded as kept, so the suggestion resolves cleanly.
        for part in ["type", "duplicate"] where !decided.contains(part) { recordQuietly(part, outcome: "kept") }
        _ = state.perform("Could not apply the decision") { () -> Ticket in
            switch choice {
            case .accept: return try IrisApplier.accept(ticketId: id, store: store)
            case .edit: return try IrisApplier.edit(ticketId: id, title: title, body: body, store: store)
            case .keep: return try IrisApplier.keepMine(ticketId: id, store: store)
            }
        }
    }

    private func acceptType(_ type: TicketType) {
        let id = ticketId
        let reason: String? = suggestion?.typeSuggestion?.reason
        let ok: Ticket? = state.perform("Could not change the type") { try state.store.changeType(id, to: type, actor: .owner, reason: reason) }
        if ok != nil { record("type", outcome: "accepted") }
    }

    private func linkDuplicate(_ other: Ticket) {
        let id = ticketId
        let otherId = other.id
        let ok: Bool? = state.perform("Could not link the tickets") { () -> Bool in
            try state.store.link(from: id, to: otherId, kind: .duplicates)
            return true
        }
        if ok != nil { record("duplicate", outcome: "linked") }
    }

    private func merge() {
        guard let other = duplicateTicket else { return }
        let id = ticketId
        let otherId = other.id
        let done: Ticket? = state.perform("Could not merge the tickets") { () -> Ticket in
            try state.store.link(from: id, to: otherId, kind: .duplicates)
            return try state.store.move(id, to: .dropped, actor: .owner, reason: "duplicate of \(other.displayNumber)")
        }
        if done != nil { record("duplicate", outcome: "merged") }
    }

    private func recordQuietly(_ part: String, outcome: String) {
        try? state.store.record(ticketId, actor: "owner", kind: "vetting-review",
                                payload: ["suggestion": .int(suggestionId), "part": .string(part), "outcome": .string(outcome)])
    }

    /// Records one part decision, then resolves the whole suggestion when there is no rewrite left to decide.
    private func record(_ part: String, outcome: String) {
        recordQuietly(part, outcome: outcome)
        decided.insert(part)
        state.refresh()
        finishWithoutRewrite()
    }

    private func finishWithoutRewrite() {
        guard let s = suggestion, s.rewrite == nil, let t = ticket else { return }
        let typeOpen = s.typeSuggestion != nil && s.typeSuggestion?.type != t.type && !decided.contains("type")
        let dupOpen = s.duplicateOf != nil && duplicateTicket != nil && !decided.contains("duplicate")
        if typeOpen || dupOpen { return }
        let id = ticketId
        let store = state.store
        _ = state.perform("Could not finish the review") { () -> Ticket in try IrisApplier.keepMine(ticketId: id, store: store) }
    }

    // MARK: Data

    private func load() {
        let current: Ticket? = try? state.store.ticket(id: ticketId)
        ticket = current
        let events: [Event] = (try? state.store.events(ticketId: ticketId, kinds: ["vetting", "vetting-resolved", "vetting-review", "vetting-failed"])) ?? []
        let pending: VettingSuggestion? = (try? state.store.pendingSuggestion(ticketId: ticketId)) ?? nil
        suggestion = pending
        var sid = 0
        if pending != nil, let last = events.last(where: { $0.kind == "vetting" }) { sid = last.id }
        suggestionId = sid
        var done = Set<String>()
        for e in events where e.kind == "vetting-review" && e.payload["suggestion"]?.intValue == sid {
            if let part = e.payload["part"]?.stringValue { done.insert(part) }
        }
        decided = done
        if let last = events.last, last.kind == "vetting-failed" {
            failure = last.payload["reason"]?.stringValue ?? "The check failed."
        } else {
            failure = nil
        }
        if let dupId = pending?.duplicateOf {
            duplicateTicket = try? state.store.ticket(id: dupId)
        } else {
            duplicateTicket = nil
        }
        openQuestionCount = ((try? state.store.questions(ticketId: ticketId, openOnly: true)) ?? []).count
    }
}

extension String {
    /// "a suggested rewrite" becomes "A suggested rewrite".
    var capitalizedFirst: String {
        guard let first = self.first else { return self }
        return first.uppercased() + self.dropFirst()
    }
}
