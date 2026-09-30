import AppKit
import Foundation
import Observation

/// The owner's feedback and each item's status, saved as JSON in the repo
/// (`EchoLab/State/lab-state.json`) so agents can read it. Only changes from a page's default
/// status are stored. The file is re-read whenever Echo Labs becomes active, so an agent's edits
/// (moving an item to In Echo, for example) show up without a restart.
@Observable @MainActor
final class LabStore {
    struct Comment: Codable, Identifiable, Equatable {
        var id = UUID()
        var date: Date
        var text: String
        /// The spec element it is about (such as "TABS-2.7"), if any.
        var element: String?
    }

    struct Event: Codable, Equatable {
        var date: Date
        var text: String
    }

    /// One revision of a round: what the agent changed since the owner last looked.
    struct Revision: Codable, Equatable, Identifiable {
        var number: Int
        var date: Date
        var summary: String
        var changes: [String] = []
        var id: Int { number }
    }

    struct Item: Codable, Equatable {
        var status: LabStatus
        var comments: [Comment] = []
        var history: [Event] = []
        /// The owner's pick per topic on a round page: topic id to option id ("none" for none).
        var picks: [String: String] = [:]
        var pickNotes: [String: String] = [:]
        /// "topic/option" to "maybe" or "no". A pick is stored in `picks`.
        var verdicts: [String: String] = [:]
        /// "topic/option" to a note about that option.
        var optionNotes: [String: String] = [:]
        /// Topics where nothing fits and the owner wants more options.
        var needsMore: [String] = []
        var generalNote: String = ""
        /// Revisions after the first look, oldest first. Revision 1 is the first version.
        var revisions: [Revision] = []
        /// The revision the owner last reviewed (sent feedback on, accepted, or marked as seen).
        var reviewedRevision: Int = 1

        init(status: LabStatus) { self.status = status }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decode(LabStatus.self, forKey: .status)
            comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
            history = try container.decodeIfPresent([Event].self, forKey: .history) ?? []
            picks = try container.decodeIfPresent([String: String].self, forKey: .picks) ?? [:]
            pickNotes = try container.decodeIfPresent([String: String].self, forKey: .pickNotes) ?? [:]
            verdicts = try container.decodeIfPresent([String: String].self, forKey: .verdicts) ?? [:]
            optionNotes = try container.decodeIfPresent([String: String].self, forKey: .optionNotes) ?? [:]
            needsMore = try container.decodeIfPresent([String].self, forKey: .needsMore) ?? []
            generalNote = try container.decodeIfPresent(String.self, forKey: .generalNote) ?? ""
            revisions = try container.decodeIfPresent([Revision].self, forKey: .revisions) ?? []
            reviewedRevision = try container.decodeIfPresent(Int.self, forKey: .reviewedRevision) ?? 1
        }
    }

    private(set) var items: [String: Item] = [:]
    private let fileURL: URL

    init(fileURL: URL = LabStore.defaultFileURL) {
        self.fileURL = fileURL
        reload()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
    }

    /// `EchoLab/State/lab-state.json`, found from this file's place in the source checkout.
    static var defaultFileURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "State/lab-state.json")
    }

    // MARK: Reading

    func status(of page: LabPage) -> LabStatus? {
        guard let base = page.status else { return nil }
        return items[page.id]?.status ?? base
    }

    func section(of page: LabPage) -> LabSection {
        status(of: page)?.section ?? page.section
    }

    /// Sidebar group: the status while ongoing, the area once decided.
    func group(of page: LabPage) -> String {
        guard let status = status(of: page) else { return page.group }
        return status == .decided ? page.group : status.rawValue
    }

    func comments(for page: LabPage) -> [Comment] { items[page.id]?.comments ?? [] }

    // MARK: Revisions

    /// The current revision number (1 until the agent records a revision).
    func revision(of page: LabPage) -> Int { items[page.id]?.revisions.last?.number ?? 1 }
    func revisions(of page: LabPage) -> [Revision] { items[page.id]?.revisions ?? [] }
    func reviewedRevision(of page: LabPage) -> Int { items[page.id]?.reviewedRevision ?? 1 }

    /// Revisions the owner has not reviewed yet: what to look for.
    func revisionsSinceReview(of page: LabPage) -> [Revision] {
        let reviewed = reviewedRevision(of: page)
        return revisions(of: page).filter { $0.number > reviewed }
    }

    /// True when something in the round was added after the owner's last review.
    func isNew(_ page: LabPage, addedIn revision: Int?) -> Bool {
        guard let revision else { return false }
        return revision > reviewedRevision(of: page)
    }

    /// The owner has now seen the current revision.
    func markReviewed(_ page: LabPage) {
        guard var item = items[page.id] else { return }
        item.reviewedRevision = item.revisions.last?.number ?? 1
        items[page.id] = item
        save()
    }
    func history(for page: LabPage) -> [Event] { items[page.id]?.history ?? [] }

    /// Items waiting for the owner: to judge, or to check in Echo.
    var attentionCount: Int {
        LabRegistry.pages.filter { [.judging, .inEcho].contains(status(of: $0)) }.count
    }

    /// Items the agent has to act on: feedback sent, or a verdict accepted.
    var agentCount: Int {
        LabRegistry.pages.filter { [.newFeedback, .accepted].contains(status(of: $0)) }.count
    }

    func count(in status: LabStatus) -> Int {
        LabRegistry.pages.filter { self.status(of: $0) == status }.count
    }

    // MARK: Owner actions

    /// The owner likes the verdict: the agent builds it into Echo.
    func accept(_ page: LabPage) { move(page, to: .accepted, note: "Accepted") }

    /// The owner checked it in the running app: the agent freezes it into the library.
    func confirm(_ page: LabPage) { move(page, to: .decided, note: "Confirmed in Echo") }

    /// Feedback always sends the item back to New feedback, from any status.
    func sendFeedback(_ page: LabPage, comment: String, element: String? = nil) {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = items[page.id] ?? Item(status: status(of: page) ?? .newFeedback)
        let wasDecided = item.status == .decided
        item.status = .newFeedback
        item.reviewedRevision = item.revisions.last?.number ?? 1
        if !text.isEmpty { item.comments.append(Comment(date: .now, text: text, element: element)) }
        item.history.append(Event(date: .now, text: wasDecided ? "Reopened with feedback" : "Feedback sent"))
        items[page.id] = item
        save()
    }

    /// Moves a decided or in-Echo item back to New feedback without a comment.
    func reopen(_ page: LabPage) { move(page, to: .newFeedback, note: "Reopened") }

    // MARK: Round picks

    func pick(_ page: LabPage, topic: String) -> String? { items[page.id]?.picks[topic] }
    func pickNote(_ page: LabPage, topic: String) -> String { items[page.id]?.pickNotes[topic] ?? "" }

    func setPick(_ page: LabPage, topic: String, option: String?) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        if let option { item.picks[topic] = option } else { item.picks.removeValue(forKey: topic) }
        items[page.id] = item
        save()
    }

    func setPickNote(_ page: LabPage, topic: String, note: String) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        if note.isEmpty { item.pickNotes.removeValue(forKey: topic) } else { item.pickNotes[topic] = note }
        items[page.id] = item
        save()
    }

    enum OptionVerdict: String { case pick, maybe, no }

    func verdict(_ page: LabPage, topic: String, option: String) -> OptionVerdict? {
        if items[page.id]?.picks[topic] == option { return .pick }
        return items[page.id]?.verdicts["\(topic)/\(option)"].flatMap(OptionVerdict.init)
    }

    /// One pick per topic; choosing Pick on another option demotes the earlier one to Maybe.
    func setVerdict(_ page: LabPage, topic: String, option: String, verdict: OptionVerdict?) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        let key = "\(topic)/\(option)"
        if item.picks[topic] == option { item.picks.removeValue(forKey: topic) }
        item.verdicts.removeValue(forKey: key)
        switch verdict {
        case .pick:
            if let previous = item.picks[topic], previous != "none" { item.verdicts["\(topic)/\(previous)"] = "maybe" }
            item.picks[topic] = option
        case .maybe, .no: item.verdicts[key] = verdict?.rawValue
        case nil: break
        }
        items[page.id] = item
        save()
    }

    func optionNote(_ page: LabPage, topic: String, option: String) -> String { items[page.id]?.optionNotes["\(topic)/\(option)"] ?? "" }

    func setOptionNote(_ page: LabPage, topic: String, option: String, note: String) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        if note.isEmpty { item.optionNotes.removeValue(forKey: "\(topic)/\(option)") } else { item.optionNotes["\(topic)/\(option)"] = note }
        items[page.id] = item
        save()
    }

    func needsMore(_ page: LabPage, topic: String) -> Bool { items[page.id]?.needsMore.contains(topic) ?? false }

    func setNeedsMore(_ page: LabPage, topic: String, _ on: Bool) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        item.needsMore.removeAll { $0 == topic }
        if on { item.needsMore.append(topic) }
        items[page.id] = item
        save()
    }

    func generalNote(_ page: LabPage) -> String { items[page.id]?.generalNote ?? "" }

    func setGeneralNote(_ page: LabPage, _ note: String) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        item.generalNote = note
        items[page.id] = item
        save()
    }

    /// Accepts the round with the picks written into a comment, so the agent reads them.
    func acceptPicks(_ page: LabPage, summary: String) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        item.status = .accepted
        item.reviewedRevision = item.revisions.last?.number ?? 1
        item.comments.append(Comment(date: .now, text: summary))
        item.history.append(Event(date: .now, text: "Accepted with picks"))
        items[page.id] = item
        save()
    }

    // MARK: Agent actions (also done by editing the JSON file)

    func markInEcho(_ page: LabPage) { move(page, to: .inEcho, note: "Built into Echo") }

    // MARK: Storage

    private func move(_ page: LabPage, to status: LabStatus, note: String) {
        var item = items[page.id] ?? Item(status: status)
        item.status = status
        item.reviewedRevision = item.revisions.last?.number ?? 1
        item.history.append(Event(date: .now, text: note))
        items[page.id] = item
        save()
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            // One bad entry must not discard the rest: decode each page's entry on its own.
            let entries = try Self.decoder.decode([String: Lossy<Item>].self, from: data)
            let stored = entries.compactMapValues(\.value)
            let bad = entries.filter { $0.value.value == nil }.keys.sorted()
            if !bad.isEmpty { NSLog("Echo Labs skipped unreadable entries in lab-state.json: \(bad.joined(separator: ", "))") }
            if stored != items { items = stored }
        } catch {
            NSLog("Echo Labs could not read lab-state.json: \(error)")
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Echo Labs could not save feedback: \(error.localizedDescription)")
        }
    }

    /// Wraps a value so a decoding failure becomes nil instead of failing the whole file.
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
