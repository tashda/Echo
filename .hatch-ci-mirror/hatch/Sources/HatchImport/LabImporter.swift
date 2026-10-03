import Foundation
import HatchCore

/// Choices for an Echo Labs import.
public struct ImportOptions: Sendable {
    /// Imported tickets stay local unless this is true. Why: the old rounds are history; creating dozens of GitHub issues
    /// should be a deliberate act, not a side effect of importing.
    public var enqueueSync: Bool
    /// Page titles, groups and round text come from Echo Labs' Swift source; without a catalog the importer falls back to the page id.
    public var catalog: LabCatalog
    /// The author given to the owner's comments.
    public var ownerName: String
    public init(enqueueSync: Bool = false, catalog: LabCatalog = .empty, ownerName: String = "owner") {
        self.enqueueSync = enqueueSync; self.catalog = catalog; self.ownerName = ownerName
    }
}

/// What an import did. `skipped` lists pages that could not be imported (with the reason); `warnings` are odd details that were tolerated.
public struct ImportReport: Equatable, Sendable {
    public var pagesSeen = 0
    public var created = 0
    public var alreadyImported = 0
    public var notes = 0
    public var events = 0
    public var picks = 0
    public var verdicts = 0
    public var revisions = 0
    public var decisions = 0
    /// Tickets created, by Hatch status raw value (`your-call`, `merged`, ...).
    public var byStatus: [String: Int] = [:]
    /// Lab page id to Hatch ticket id, for created and already imported pages alike.
    public var ticketIds: [String: Int] = [:]
    public var skipped: [String] = []
    public var warnings: [String] = []
    public init() {}
}

/// Brings Echo Labs rounds into Hatch as Proposal tickets (decision L4).
public enum LabImporter {
    /// Echo Labs' status names to Hatch statuses. Nil for a name we do not know.
    public static func hatchStatus(forLabStatus s: String) -> Status? {
        switch s.trimmingCharacters(in: .whitespaces).lowercased() {
        case "judging": return .yourCall
        case "new feedback": return .revising
        case "accepted": return .accepted
        case "in echo": return .merged
        case "decided": return .done
        default: return nil
        }
    }

    /// The last line of an imported ticket's body. Re-importing looks for it, so it must stay exactly this shape.
    public static func marker(_ pageID: String) -> String { "lab-page: \(pageID)" }

    /// Reads `lab-state.json` and imports every page. Safe to run again: pages whose marker is already in the project are left alone.
    @discardableResult
    public static func importState(file: URL, project: Project, store: HatchStore, options: ImportOptions = ImportOptions()) throws -> ImportReport {
        try importState(data: Data(contentsOf: file), project: project, store: store, options: options)
    }

    @discardableResult
    public static func importState(data: Data, project: Project, store: HatchStore, options: ImportOptions = ImportOptions()) throws -> ImportReport {
        var report = ImportReport()
        let root: JSONValue
        do { root = try JSONDecoder().decode(JSONValue.self, from: data) } catch {
            throw StoreError.invalid("lab-state.json is not valid JSON: \(error)")
        }
        guard let pages = root.objectValue else { throw StoreError.invalid("lab-state.json should hold an object keyed by page id.") }
        let parser = DateParser()
        // Oldest first, so ticket numbers follow the order the rounds happened in.
        let ordered = pages.keys.sorted { a, b in
            let da = firstDate(pages[a]!, parser) ?? .distantFuture, db = firstDate(pages[b]!, parser) ?? .distantFuture
            return da == db ? a < b : da < db
        }
        for id in ordered {
            report.pagesSeen += 1
            guard let page = pages[id]?.objectValue else { report.skipped.append("\(id): not an object"); continue }
            do {
                try importPage(id: id, page: page, project: project, store: store, options: options, parser: parser, report: &report)
            } catch {
                report.skipped.append("\(id): \(error)")
            }
        }
        return report
    }

    // MARK: One page

    private static func importPage(id: String, page: [String: JSONValue], project: Project, store: HatchStore,
                                   options: ImportOptions, parser: DateParser, report: inout ImportReport) throws {
        if let existing = try existingTicket(pageID: id, project: project, store: store) {
            report.alreadyImported += 1
            report.ticketIds[id] = existing
            return
        }
        guard let labStatus = page["status"]?.stringValue else { throw StoreError.invalid("no status") }
        guard let status = hatchStatus(forLabStatus: labStatus) else { throw StoreError.invalid("unknown status \"\(labStatus)\"") }

        let comments = (page["comments"]?.arrayValue ?? []).compactMap { $0.objectValue }
        let history = (page["history"]?.arrayValue ?? []).compactMap { $0.objectValue }
        let revisions = (page["revisions"]?.arrayValue ?? []).compactMap { $0.objectValue }
        var dates: [Date] = []
        for o in comments + history + revisions {
            if let s = o["date"]?.stringValue {
                if let d = parser.parse(s) { dates.append(d) } else { report.warnings.append("\(id): unreadable date \"\(s)\"") }
            }
        }
        if let d = page["takenBy"]?["date"]?.stringValue.flatMap(parser.parse) { dates.append(d) }
        let fallback = store.now()
        if dates.isEmpty { report.warnings.append("\(id): no dates, using the import time") }
        let created = dates.min() ?? fallback, updated = dates.max() ?? fallback

        let info = options.catalog.pages[id], round = options.catalog.round(forPage: id)
        let title = info?.title ?? humanTitle(id)
        let body = buildBody(id: id, info: info, round: round, status: labStatus)

        try store.db.transaction {
            let ticket = try store.createTicket(projectId: project.id, type: .proposal, title: title, body: body, area: info?.group, status: .draft)
            let tid = ticket.id
            var eventCount = 0

            // Owner comments, with their original times and ids (the id keeps a later re-sync from duplicating them).
            for c in comments {
                guard let text = c["text"]?.stringValue, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                let at = c["date"]?.stringValue.flatMap(parser.parse) ?? created
                var ctx: [String: JSONValue] = ["source": "lab-comment"]
                if let cid = c["id"]?.stringValue { ctx["lab-comment-id"] = .string(cid) }
                try store.addNote(tid, kind: .comment, author: options.ownerName, body: text, context: .object(ctx), at: at)
                report.notes += 1
            }
            if let general = page["generalNote"]?.stringValue, !general.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let at = comments.last?["date"]?.stringValue.flatMap(parser.parse) ?? created
                try store.addNote(tid, kind: .note, author: options.ownerName, body: general, context: ["source": "generalNote"], at: at)
                report.notes += 1
            }

            // Picks (topic to choice) and the owner's words about a pick.
            let pickNotes = page["pickNotes"]?.objectValue ?? [:]
            for (topic, value) in (page["picks"]?.objectValue ?? [:]).sorted(by: { $0.key < $1.key }) {
                let note = pickNotes[topic].flatMap(text(of:))
                try store.setPick(ticketId: tid, topic: topic, choice: text(of: value) ?? value.jsonString(), note: note)
                report.picks += 1
            }
            for (topic, value) in pickNotes.sorted(by: { $0.key < $1.key }) {
                guard let t = text(of: value), !t.isEmpty else { continue }
                try store.addNote(tid, kind: .note, author: options.ownerName, body: t, context: ["source": "pickNote", "topic": .string(topic)], at: updated)
                report.notes += 1
            }
            // Verdicts are keyed "topic/option" (for example "exhibit/cards"): Pick, Maybe or No.
            for (key, value) in (page["verdicts"]?.objectValue ?? [:]).sorted(by: { $0.key < $1.key }) {
                let (topic, option) = splitKey(key)
                guard let verdict = value.stringValue?.lowercased(), ["pick", "maybe", "no"].contains(verdict) else {
                    report.warnings.append("\(id): verdict \"\(key)\" has an unknown value, skipped"); continue
                }
                try store.setVerdict(ticketId: tid, topic: topic, option: option, verdict: verdict)
                report.verdicts += 1
            }
            for (key, value) in (page["optionNotes"]?.objectValue ?? [:]).sorted(by: { $0.key < $1.key }) {
                guard let t = text(of: value), !t.isEmpty else { continue }
                let (topic, option) = splitKey(key)
                try store.addNote(tid, kind: .note, author: options.ownerName, body: t,
                                  context: ["source": "optionNote", "topic": .string(topic), "option": .string(option)], at: updated)
                report.notes += 1
            }
            let needsMore = (page["needsMore"]?.arrayValue ?? []).compactMap { $0.stringValue }
            if !needsMore.isEmpty {
                try store.addNote(tid, kind: .note, author: options.ownerName, body: "Needs more options: " + needsMore.joined(separator: ", "),
                                  context: ["source": "needsMore", "topics": .array(needsMore.map { .string($0) })], at: updated)
                report.notes += 1
            }

            // Revisions: the agent's hand-ins. Keep Echo Labs' numbering.
            var revisionDates: [Int: Date] = [:]
            for r in revisions.sorted(by: { ($0["number"]?.intValue ?? 0) < ($1["number"]?.intValue ?? 0) }) {
                guard let summary = r["summary"]?.stringValue else { report.warnings.append("\(id): a revision has no summary, skipped"); continue }
                let current = try store.ticket(id: tid)?.revision ?? 1
                if let n = r["number"]?.intValue, n > current { try store.setRevisionNumber(ticketId: tid, n - 1) }
                let n = try store.recordRevision(ticketId: tid, summary: summary, added: (r["changes"]?.arrayValue ?? []).compactMap { $0.stringValue })
                let at = r["date"]?.stringValue.flatMap(parser.parse) ?? updated
                try store.setRevisionTime(ticketId: tid, n: n, at: at)
                revisionDates[n] = at
                report.revisions += 1
            }

            // A decided page also becomes a Decision (the frozen result in the Decisions library).
            if status == .done {
                let summary = decisionText(round: round, page: page, history: history)
                let codes = specCodes(in: summary + " " + (info?.summary ?? ""))
                try store.recordDecision(ticketId: tid, summary: summary, specCodes: codes)
                report.decisions += 1
            }
            try store.backdateImported(ticketId: tid, to: updated)

            // History: replace the "now" events the calls above wrote with the real, dated ones.
            try store.clearEvents(ticketId: tid)
            try store.recordEvent(tid, actor: "owner", kind: "created", payload: ["type": "proposal", "status": .string(status.rawValue)], at: created); eventCount += 1
            for h in history {
                guard let text = h["text"]?.stringValue else { continue }
                let at = h["date"]?.stringValue.flatMap(parser.parse) ?? created
                try store.recordEvent(tid, actor: historyActor(text), kind: "history", payload: ["text": .string(text), "source": "lab-state"], at: at); eventCount += 1
            }
            if let taken = page["takenBy"]?.objectValue, let agent = taken["agent"]?.stringValue {
                let at = taken["date"]?.stringValue.flatMap(parser.parse) ?? updated
                try store.recordEvent(tid, actor: agent, kind: "taken", payload: ["status": taken["status"] ?? .null], at: at); eventCount += 1
            }
            try store.recordEvent(tid, actor: "hatch", kind: "status",
                                  payload: ["from": .null, "to": .string(status.rawValue), "reason": .string("imported from Echo Labs (\(labStatus))")], at: updated); eventCount += 1
            try store.recordEvent(tid, actor: "import", kind: "imported",
                                  payload: ["lab-page": .string(id), "lab-status": .string(labStatus),
                                            "reviewedRevision": page["reviewedRevision"] ?? .null], at: fallback); eventCount += 1
            report.events += eventCount

            // Only an agent-turn status keeps a claim on the ticket.
            let takenBy = status.turn == .agent ? page["takenBy"]?["agent"]?.stringValue : nil
            try store.setImportedState(tid, status: status, createdAt: created, updatedAt: updated, takenBy: takenBy)
            try store.indexTicket(tid)

            if options.enqueueSync {
                try store.enqueueCreateIssue(tid)
                if status == .done { try store.enqueueClose(tid, reason: "completed") }
            }
            report.created += 1
            report.byStatus[status.rawValue, default: 0] += 1
            report.ticketIds[id] = tid
        }
    }

    // MARK: Helpers

    /// A ticket of this project whose body has the marker as a whole line. The substring query is only a cheap filter.
    static func existingTicket(pageID: String, project: Project, store: HatchStore) throws -> Int? {
        let line = marker(pageID)
        for id in try store.ticketIds(projectId: project.id, bodyContaining: line) {
            guard let t = try store.ticket(id: id) else { continue }
            if t.body.split(whereSeparator: \.isNewline).contains(where: { $0.trimmingCharacters(in: .whitespaces) == line }) { return id }
        }
        return nil
    }

    /// `ongoing.content-during-slide-r26` becomes "Content during slide".
    static func humanTitle(_ pageID: String) -> String {
        var s = pageID
        if let dot = s.firstIndex(of: ".") { s = String(s[s.index(after: dot)...]) }
        var parts = s.split(separator: "-").map(String.init)
        if let last = parts.last, last.count >= 2, last.first == "r", last.dropFirst().allSatisfy(\.isNumber) { parts.removeLast() }
        let words = parts.joined(separator: " ")
        return words.isEmpty ? pageID : words.prefix(1).uppercased() + words.dropFirst()
    }

    static func buildBody(id: String, info: LabCatalog.Page?, round: LabCatalog.Round?, status: String) -> String {
        var lines: [String] = []
        if let s = info?.summary, !s.isEmpty { lines.append(s) }
        if let r = round {
            var head = "**\(r.label): \(r.title)**"
            if !r.date.isEmpty { head += " (\(r.date))" }
            lines.append(head)
            if !r.asked.isEmpty { lines.append("**Asked:** \(r.asked)") }
            if !r.outcome.isEmpty { lines.append("**Outcome in Echo Labs:** \(r.outcome)") }
        }
        lines.append("Imported from Echo Labs. Status there: \(status).")
        return lines.joined(separator: "\n\n") + "\n\n---\n" + marker(id)
    }

    static func decisionText(round: LabCatalog.Round?, page: [String: JSONValue], history: [[String: JSONValue]]) -> String {
        if let o = round?.outcome.trimmingCharacters(in: .whitespacesAndNewlines), !o.isEmpty, o.lowercased() != "being judged." { return o }
        if let revision = (page["revisions"]?.arrayValue ?? []).last?["summary"]?.stringValue, !revision.isEmpty { return revision }
        if let g = page["generalNote"]?.stringValue, !g.isEmpty { return g }
        if let h = history.last?["text"]?.stringValue { return h }
        let picks = (page["picks"]?.objectValue ?? [:]).sorted { $0.key < $1.key }.compactMap { k, v in text(of: v).map { "\(k): \($0)" } }
        return picks.isEmpty ? "Decided in Echo Labs." : "Picked " + picks.joined(separator: "; ")
    }

    /// Spec ids such as `TABS-2.7` mentioned in text.
    static func specCodes(in text: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"\b[A-Z][A-Z0-9]{1,5}-\d+(?:\.\d+)*"#) else { return [] }
        let ns = text as NSString
        var seen = Set<String>(), out: [String] = []
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let code = ns.substring(with: m.range)
            if seen.insert(code).inserted { out.append(code) }
        }
        return out
    }

    private static func text(of v: JSONValue) -> String? {
        switch v {
        case .string(let s): return s
        case .number(let d): return d == d.rounded() ? String(Int(d)) : String(d)
        case .bool(let b): return String(b)
        case .array(let a): return a.compactMap(text(of:)).joined(separator: "; ")
        default: return nil
        }
    }

    private static func splitKey(_ key: String) -> (topic: String, option: String) {
        guard let slash = key.firstIndex(of: "/") else { return (key, "") }
        return (String(key[..<slash]), String(key[key.index(after: slash)...]))
    }

    /// Who did it, from the wording of Echo Labs' history lines.
    private static func historyActor(_ text: String) -> String {
        let t = text.lowercased()
        if t.hasPrefix("feedback sent") || t.hasPrefix("accepted") || t.hasPrefix("confirmed") || t.hasPrefix("decided") { return "owner" }
        return "agent"
    }

    private static func firstDate(_ page: JSONValue, _ parser: DateParser) -> Date? {
        var dates: [Date] = []
        for key in ["comments", "history", "revisions"] {
            for item in page[key]?.arrayValue ?? [] { if let d = item["date"]?.stringValue.flatMap(parser.parse) { dates.append(d) } }
        }
        return dates.min()
    }
}

/// Reads the two date shapes that appear in Echo Labs state: `2026-10-01T09:54:10Z`, with or without fractional seconds.
final class DateParser {
    private let plain = ISO8601DateFormatter()
    private let fractional: ISO8601DateFormatter
    init() {
        fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    func parse(_ s: String) -> Date? { plain.date(from: s) ?? fractional.date(from: s) }
}
