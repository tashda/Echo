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
    }

    struct Event: Codable, Equatable {
        var date: Date
        var text: String
    }

    struct Item: Codable, Equatable {
        var status: LabStatus
        var comments: [Comment] = []
        var history: [Event] = []
        /// The owner's pick per topic on a round page: topic id to option id ("none" for none).
        var picks: [String: String] = [:]
        var pickNotes: [String: String] = [:]

        init(status: LabStatus) { self.status = status }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decode(LabStatus.self, forKey: .status)
            comments = try container.decodeIfPresent([Comment].self, forKey: .comments) ?? []
            history = try container.decodeIfPresent([Event].self, forKey: .history) ?? []
            picks = try container.decodeIfPresent([String: String].self, forKey: .picks) ?? [:]
            pickNotes = try container.decodeIfPresent([String: String].self, forKey: .pickNotes) ?? [:]
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
    func history(for page: LabPage) -> [Event] { items[page.id]?.history ?? [] }

    /// Items waiting for someone: new feedback, judging, accepted, or in Echo.
    var attentionCount: Int {
        LabRegistry.pages.filter { [.newFeedback, .judging, .accepted, .inEcho].contains(status(of: $0)) }.count
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
    func sendFeedback(_ page: LabPage, comment: String) {
        let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        var item = items[page.id] ?? Item(status: status(of: page) ?? .newFeedback)
        let wasDecided = item.status == .decided
        item.status = .newFeedback
        if !text.isEmpty { item.comments.append(Comment(date: .now, text: text)) }
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

    /// Accepts the round with the picks written into a comment, so the agent reads them.
    func acceptPicks(_ page: LabPage, summary: String) {
        var item = items[page.id] ?? Item(status: status(of: page) ?? .judging)
        item.status = .accepted
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
        item.history.append(Event(date: .now, text: note))
        items[page.id] = item
        save()
    }

    func reload() {
        guard let data = try? Data(contentsOf: fileURL),
              let stored = try? Self.decoder.decode([String: Item].self, from: data) else { return }
        if stored != items { items = stored }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(items).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Echo Labs could not save feedback: \(error.localizedDescription)")
        }
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
