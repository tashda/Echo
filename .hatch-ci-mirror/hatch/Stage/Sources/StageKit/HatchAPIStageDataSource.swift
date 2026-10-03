// ADAPTER POINT: this is the only file in StageKit that knows Hatch's local API.
//
// It wraps `HatchAPI.StageClient` (decision S3: Hatch is the only writer; writes that cannot be delivered wait in the client's
// outbox and are replayed in order, decision S7). The orchestrator should check this file against the real `StageClient`
// when wiring the Stage into the app.
import Foundation
import StageCore
import HatchAPI
import HatchCore

public final class HatchAPIStageDataSource: StageDataSource {
    private let client: StageClient
    private let ref: String

    /// - Parameter ticket: the ticket reference Hatch understands ("151" or "#151").
    public init(ticket: String, client: StageClient = StageClient()) {
        self.ref = ticket
        self.client = client
    }

    /// For `--home <dir>`: Hatch's support directory as the app that launched this Stage passes it.
    public convenience init(ticket: String, home: URL) {
        self.init(ticket: ticket, client: StageClient(paths: HatchPaths(home: home)))
    }

    // MARK: Helpers

    /// `StageClient` is synchronous and blocking, so it runs off the main thread.
    private func blocking<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let value = try work()
                    continuation.resume(returning: value)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func translate(_ error: Error) -> Error {
        if let e = error as? StageClientError {
            switch e {
            case .unreachable(let message):
                return StageDataSourceError.unreachable(message)
            case .server(let status, let code, let message):
                return StageDataSourceError.refused("\(status) \(code): \(message)")
            }
        }
        return error
    }

    private func delivery(_ d: HatchAPI.StageDelivery) -> StageCore.StageDelivery {
        d == .delivered ? StageCore.StageDelivery.delivered : StageCore.StageDelivery.queued
    }

    private var stateURL: URL {
        let safe = ref.map { ch -> Character in (ch.isLetter || ch.isNumber) ? ch : "_" }
        return client.paths.stageHome.appendingPathComponent("state-\(String(safe)).json")
    }

    // MARK: Loading

    public func loadManifest() async throws -> StageManifest {
        let json: JSONValue
        do {
            json = try await blocking { try self.client.proposal(ref: self.ref) }
        } catch {
            throw translate(error)
        }
        guard case .object(let object) = json, let manifestValue = object["manifest"], case .string(let text) = manifestValue else {
            throw StageDataSourceError.noManifest("Hatch has no manifest for \(ref).")
        }
        return try StageManifest.parse(json: text)
    }

    /// The state remembered on this Mac. Hatch's copy of the answers, verdicts and pins is merged over it by the model
    /// (`loadSnapshot`), so this file is only a cache and a pick is never kept only here.
    public func loadState() async throws -> StageState? {
        guard let data = try? Data(contentsOf: stateURL) else { return nil }
        return try? JSONDecoder().decode(StageState.self, from: data)
    }

    /// Hatch's picks, verdicts, pins and revision summaries, or `nil` when Hatch cannot be reached.
    public func loadSnapshot() async -> StageHatchSnapshot? {
        guard let json = try? await blocking({ try self.client.proposal(ref: self.ref) }), case .object(let object) = json else { return nil }
        var snapshot = StageHatchSnapshot()
        for item in object["picks"]?.arrayValue ?? [] {
            guard let topic = item["topic"]?.stringValue, let choice = item["choice"]?.stringValue else { continue }
            snapshot.picks.append(.init(topic: topic, choice: choice, note: item["note"]?.stringValue))
        }
        for item in object["verdicts"]?.arrayValue ?? [] {
            guard let topic = item["topic"]?.stringValue, let option = item["option"]?.stringValue, let word = item["verdict"]?.stringValue else { continue }
            snapshot.verdicts.append(.init(topic: topic, option: option, verdict: word, note: item["note"]?.stringValue))
        }
        for item in object["pins"]?.arrayValue ?? [] {
            guard let id = item["id"]?.intValue, let text = item["text"]?.stringValue else { continue }
            snapshot.pins.append(.init(id: id, text: text, option: item["option"]?.stringValue, x: item["x"]?.doubleValue, y: item["y"]?.doubleValue,
                                       scenario: item["scenario"]?.stringValue, appearance: item["appearance"]?.stringValue,
                                       corners: item["corners"]?.intValue, zoom: item["zoom"]?.doubleValue))
        }
        for item in object["revisions"]?.arrayValue ?? [] {
            guard let n = item["n"]?.intValue, let summary = item["summary"]?.stringValue else { continue }
            snapshot.revisionSummaries[n] = summary
        }
        return snapshot
    }

    public func heartbeat(revision: Int, state: String) async -> StageHeartbeatReply? {
        let pid = Int(ProcessInfo.processInfo.processIdentifier)
        guard let json = try? await blocking({ try self.client.heartbeat(ticket: self.ref, revision: revision, pid: pid, state: state) }),
              let latest = json["latestRevision"]?.intValue else { return nil }
        let status = json["status"]?.stringValue ?? ""
        return StageHeartbeatReply(latestRevision: latest, reload: json["reload"]?.boolValue ?? false,
                                   open: status == "your-call" || status == "revising" || status.isEmpty)
    }

    public func saveState(_ state: StageState) async {
        do {
            try FileManager.default.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            // The state is a convenience; the picks themselves are in Hatch's outbox.
        }
    }

    // MARK: Writes

    public func postPick(topic: String, choice: String, note: String?) async throws -> StageCore.StageDelivery {
        do {
            let d = try await blocking { try self.client.pick(ref: self.ref, topic: topic, choice: choice, note: note) }
            return delivery(d)
        } catch {
            throw translate(error)
        }
    }

    public func postVerdict(topic: String, option: String, verdict: String, note: String?) async throws -> StageCore.StageDelivery {
        do {
            let d = try await blocking { try self.client.verdict(ref: self.ref, topic: topic, option: option, verdict: verdict, note: note) }
            return delivery(d)
        } catch {
            throw translate(error)
        }
    }

    public func postPin(_ pin: StagePin) async throws -> StageCore.StageDelivery {
        do {
            let d = try await blocking {
                try self.client.pin(ref: self.ref, text: pin.text, option: pin.option, x: pin.x, y: pin.y, scenario: pin.scenario,
                                    appearance: pin.appearance.rawValue, corners: pin.corners, zoom: pin.zoom)
            }
            return delivery(d)
        } catch {
            throw translate(error)
        }
    }

    public func postNote(kind: String, body: String) async throws -> StageCore.StageDelivery {
        try await postNote(kind: kind, body: body, screenshot: nil)
    }

    /// A question carries a JPEG of the view (decision H14). Hatch keeps it as an attachment of the ticket.
    public func postNote(kind: String, body: String, screenshot: Data?) async throws -> StageCore.StageDelivery {
        do {
            let d = try await blocking { try self.client.note(ref: self.ref, kind: kind, body: body, screenshot: screenshot) }
            return delivery(d)
        } catch {
            throw translate(error)
        }
    }

    public func accept(choices: [String: String]) async throws {
        do {
            _ = try await blocking { try self.client.accept(ref: self.ref, choices: choices) }
        } catch {
            throw translate(error)
        }
    }

    public func sendBack(reason: String, note: String) async throws {
        do {
            _ = try await blocking { try self.client.sendBack(ref: self.ref, reason: reason, note: note) }
        } catch {
            throw translate(error)
        }
    }

    public func pendingCount() async -> Int {
        client.pendingCount
    }
}
