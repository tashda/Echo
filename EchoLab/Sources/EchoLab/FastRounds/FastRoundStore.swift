import Foundation
import Observation

/// Reads `EchoLab/State/fast-rounds/*.json` and keeps watching it, so an agent can add or change a
/// fast round while Echo Labs is open and it appears in the Inbox within a second.
@Observable @MainActor
final class FastRoundStore {
    static let shared = FastRoundStore()

    private(set) var rounds: [FastRound] = []
    /// The rounds as lab pages, so the Inbox, status and feedback treat them like any other item.
    private(set) var pages: [LabPage] = []

    private let directory = LabStore.defaultFileURL.deletingLastPathComponent().appending(path: "fast-rounds")
    private var signature = ""
    private var watcher: Task<Void, Never>?

    private init() { reload() }

    func round(forPage id: String) -> FastRound? { rounds.first { $0.id == id } }

    func startWatching() {
        guard watcher == nil else { return }
        watcher = Task(name: "echolab-watch-fast-rounds") { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.reloadIfChanged()
            }
        }
    }

    private func files() -> [URL] {
        let all = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return all.filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func reloadIfChanged() {
        let now = files().map { url in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return "\(url.lastPathComponent)@\(date?.timeIntervalSince1970 ?? 0)"
        }.joined(separator: "|")
        if now != signature { reload() }
    }

    func reload() {
        let decoder = JSONDecoder()
        var loaded: [FastRound] = []
        var seen = ""
        for url in files() {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            seen += "\(url.lastPathComponent)@\(date?.timeIntervalSince1970 ?? 0)|"
            do {
                var round = try decoder.decode(FastRound.self, from: Data(contentsOf: url))
                round.slug = url.deletingPathExtension().lastPathComponent
                loaded.append(round)
            } catch {
                NSLog("Echo Labs skipped fast round \(url.lastPathComponent): \(error)")
            }
        }
        signature = String(seen.dropLast())
        rounds = loaded
        pages = loaded.map(Self.page)
    }

    private static func page(for round: FastRound) -> LabPage {
        let area = LabAreas.all.first { $0.id == round.area || $0.title.lowercased() == round.area.lowercased() }
        let id = round.id
        return LabPage(id: id, section: .ongoing, group: area?.title ?? round.area, title: round.title, symbol: "bolt",
                       status: .judging, summary: round.summary.isEmpty ? round.feedback : round.summary) {
            FastRoundBody(pageID: id)
        }
    }
}
