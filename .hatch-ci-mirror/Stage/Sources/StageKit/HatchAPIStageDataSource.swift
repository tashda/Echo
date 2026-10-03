// ADAPTER POINT: this is the only file in StageKit that knows Hatch's local API.
//
// It wraps `HatchAPI.StageClient` (decision S3: Hatch is the only writer; writes that cannot be delivered wait in the client's
// outbox and are replayed in order, decision S7). The orchestrator should check this file against the real `StageClient`
// when wiring the Stage into the app. Known gaps are marked ADAPTER GAP.
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

    /// The state remembered on this Mac, with the answers and verdicts Hatch has recorded laid over it.
    public func loadState() async throws -> StageState? {
        var state: StageState? = nil
        if let data = try? Data(contentsOf: stateURL) {
            state = try? JSONDecoder().decode(StageState.self, from: data)
        }
        // ADAPTER GAP: pins and notes are kept in the local state file only; Hatch's copy is not merged back.
        let json = try? await blocking { try self.client.proposal(ref: self.ref) }
        guard let proposal = json, case .object(let object) = proposal else { return state }
        var merged: StageState = state ?? StageState()
        if let picks = object["picks"]?.arrayValue {
            for pick in picks {
                if case .object(let p) = pick, let topic = p["topic"]?.stringValue, let choice = p["choice"]?.stringValue {
                    merged.answers[topic] = choice
                }
            }
        }
        if let verdicts = object["verdicts"]?.arrayValue {
            for item in verdicts {
                if case .object(let v) = item, let option = v["option"]?.stringValue, let word = v["verdict"]?.stringValue,
                   let verdict = StageVerdict(rawValue: word) {
                    merged.verdicts[option] = verdict
                }
            }
        }
        return merged
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
        // ADAPTER GAP: the local API has no way to clear a verdict. The Stage sends "none" when the owner toggles one off;
        // it is kept locally and not sent. Add a clear endpoint to StageServer, then send it here.
        if verdict == "none" { return StageCore.StageDelivery.delivered }
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
        // ADAPTER GAP: "ask" should carry a picture of the current view (decision H14); StageClient has no attachment yet.
        do {
            let d = try await blocking { try self.client.note(ref: self.ref, kind: kind, body: body) }
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
