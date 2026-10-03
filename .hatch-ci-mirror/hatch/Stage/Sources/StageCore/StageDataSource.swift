import Foundation

/// Whether a write reached Hatch now or was kept for later (decision S7: the Stage never loses a pick).
public enum StageDelivery: Equatable {
    case delivered, queued
}

public enum StageDataSourceError: Error, CustomStringConvertible, Equatable {
    /// Hatch is not reachable and the call cannot wait (Accept, Send back).
    case unreachable(String)
    case refused(String)
    case noManifest(String)
    public var description: String {
        switch self {
        case .unreachable(let m): return "Hatch is not reachable: \(m)"
        case .refused(let m): return "Hatch refused: \(m)"
        case .noManifest(let m): return "No Proposal to show: \(m)"
        }
    }
}

/// Hatch's answer to a heartbeat: is there a newer revision than the one on screen, and is the Proposal still open for judging.
public struct StageHeartbeatReply: Equatable {
    public var latestRevision: Int
    public var reload: Bool
    public var open: Bool
    public init(latestRevision: Int, reload: Bool, open: Bool = true) {
        self.latestRevision = latestRevision; self.reload = reload; self.open = open
    }
}

/// Where the Stage gets its Proposal from and where its picks go. Hatch is the only writer (decision S3), so the real
/// implementation talks to Hatch's local API; the in-memory one serves `--demo` and the tests.
public protocol StageDataSource: AnyObject {
    func loadManifest() async throws -> StageManifest
    /// The state remembered for this ticket, or `nil` when there is none yet.
    func loadState() async throws -> StageState?
    /// Keeps the state for the next launch (per ticket, decision H7).
    func saveState(_ state: StageState) async

    @discardableResult func postPick(topic: String, choice: String, note: String?) async throws -> StageDelivery
    @discardableResult func postVerdict(topic: String, option: String, verdict: String, note: String?) async throws -> StageDelivery
    @discardableResult func postPin(_ pin: StagePin) async throws -> StageDelivery
    /// `kind` is note, ask or instruction.
    @discardableResult func postNote(kind: String, body: String) async throws -> StageDelivery
    /// Accept starts agent work and costs tokens, so it throws when Hatch is away instead of queueing.
    func accept(choices: [String: String]) async throws
    func sendBack(reason: String, note: String) async throws
    /// How many writes wait for Hatch.
    func pendingCount() async -> Int

    /// A question with a picture of the current view (decision H14). `screenshot` is JPEG or PNG data; the source that cannot
    /// carry a picture sends the text alone.
    @discardableResult func postNote(kind: String, body: String, screenshot: Data?) async throws -> StageDelivery
    /// Tells Hatch this Stage is alive and which revision it shows (`state` is running, idle or closed). `nil` when Hatch cannot
    /// be reached or the source has no Hatch behind it. A late heartbeat is worthless, so it is never queued.
    func heartbeat(revision: Int, state: String) async -> StageHeartbeatReply?
    /// Hatch's copy of the picks, verdicts and pins, to merge over the remembered state. `nil` when Hatch cannot be reached.
    func loadSnapshot() async -> StageHatchSnapshot?
}

extension StageDataSource {
    public func pendingCount() async -> Int { 0 }
    public func postNote(kind: String, body: String, screenshot: Data?) async throws -> StageDelivery {
        try await postNote(kind: kind, body: body)
    }
    public func heartbeat(revision: Int, state: String) async -> StageHeartbeatReply? { nil }
    public func loadSnapshot() async -> StageHatchSnapshot? { nil }

    /// Sends one effect of the reducer. The result says whether it was delivered, queued, or needs no waiting.
    @discardableResult
    public func perform(_ effect: StageEffect, screenshot: Data? = nil) async throws -> StageDelivery {
        switch effect {
        case .pick(let topic, let choice, let note):
            return try await postPick(topic: topic, choice: choice, note: note)
        case .verdict(let topic, let option, let verdict, let note):
            return try await postVerdict(topic: topic, option: option, verdict: verdict, note: note)
        case .pin(let pin):
            return try await postPin(pin)
        case .note(let kind, let body):
            // Only a question carries the picture of the view (decision H14).
            if kind == "ask", let screenshot { return try await postNote(kind: kind, body: body, screenshot: screenshot) }
            return try await postNote(kind: kind, body: body)
        case .accept(let choices):
            try await accept(choices: choices)
            return .delivered
        case .sendBack(let reason, let note):
            try await sendBack(reason: reason, note: note)
            return .delivered
        }
    }
}

/// What the in-memory source recorded, in order. Tests read it.
public struct StageRecordedEvent: Equatable {
    public enum Kind: Equatable {
        case pick, verdict, pin, note, accept, sendBack
    }
    public var kind: Kind
    public var fields: [String: String]
    public init(kind: Kind, fields: [String: String]) { self.kind = kind; self.fields = fields }
}

/// A data source that keeps everything in memory. Used by `--demo` (a round runs without Hatch) and by tests.
public final class InMemoryStageDataSource: StageDataSource {
    private let lock = NSLock()
    private var manifest: StageManifest
    private var savedState: StageState?
    private var recorded: [StageRecordedEvent] = []
    private var away = false
    private var queued = 0
    private var beats: [String] = []
    private var reply: StageHeartbeatReply?
    private var snapshot: StageHatchSnapshot?

    public init(manifest: StageManifest, state: StageState? = nil) {
        self.manifest = manifest
        self.savedState = state
    }

    /// Set to simulate Hatch being away: writes are queued, Accept and Send back throw.
    public var hatchAway: Bool {
        get { lock.withLock { away } }
        set { lock.withLock { away = newValue } }
    }

    public var events: [StageRecordedEvent] { lock.withLock { recorded } }

    /// What the next heartbeats answer; tests set it to simulate Hatch announcing a new revision.
    public var heartbeatReply: StageHeartbeatReply? {
        get { lock.withLock { reply } }
        set { lock.withLock { reply = newValue } }
    }
    /// What `loadSnapshot` returns; tests set it to simulate Hatch holding answers the Stage does not have.
    public var hatchSnapshot: StageHatchSnapshot? {
        get { lock.withLock { snapshot } }
        set { lock.withLock { snapshot = newValue } }
    }
    /// The states of the heartbeats received, in order.
    public var heartbeats: [String] { lock.withLock { beats } }

    // The lock is only taken in these synchronous helpers (NSLock must not be held across an await).
    private func currentManifest() -> StageManifest { lock.withLock { manifest } }
    private func currentState() -> StageState? { lock.withLock { savedState } }
    private func store(_ state: StageState) { lock.withLock { savedState = state } }
    private func queuedCount() -> Int { lock.withLock { queued } }

    private func record(_ kind: StageRecordedEvent.Kind, _ fields: [String: String]) -> StageDelivery {
        lock.withLock {
            recorded.append(StageRecordedEvent(kind: kind, fields: fields))
            if away { queued += 1; return .queued }
            return .delivered
        }
    }

    public func loadManifest() async throws -> StageManifest { currentManifest() }
    public func loadState() async throws -> StageState? { currentState() }
    public func saveState(_ state: StageState) async { store(state) }
    public func pendingCount() async -> Int { queuedCount() }

    public func postPick(topic: String, choice: String, note: String?) async throws -> StageDelivery {
        record(.pick, ["topic": topic, "choice": choice, "note": note ?? ""])
    }

    public func postVerdict(topic: String, option: String, verdict: String, note: String?) async throws -> StageDelivery {
        record(.verdict, ["topic": topic, "option": option, "verdict": verdict, "note": note ?? ""])
    }

    public func postPin(_ pin: StagePin) async throws -> StageDelivery {
        record(.pin, ["id": pin.id, "text": pin.text, "option": pin.option ?? "", "scenario": pin.scenario,
                      "appearance": pin.appearance.rawValue, "corners": String(pin.corners), "zoom": String(pin.zoom)])
    }

    public func postNote(kind: String, body: String) async throws -> StageDelivery {
        record(.note, ["kind": kind, "body": body])
    }

    public func postNote(kind: String, body: String, screenshot: Data?) async throws -> StageDelivery {
        var fields = ["kind": kind, "body": body]
        if let screenshot { fields["screenshotBytes"] = String(screenshot.count) }
        return record(.note, fields)
    }

    public func heartbeat(revision: Int, state: String) async -> StageHeartbeatReply? {
        lock.withLock {
            beats.append(state)
            return away ? nil : reply
        }
    }

    public func loadSnapshot() async -> StageHatchSnapshot? {
        lock.withLock { away ? nil : snapshot }
    }

    public func accept(choices: [String: String]) async throws {
        if hatchAway { throw StageDataSourceError.unreachable("demo source is set to away") }
        _ = record(.accept, choices)
    }

    public func sendBack(reason: String, note: String) async throws {
        if hatchAway { throw StageDataSourceError.unreachable("demo source is set to away") }
        _ = record(.sendBack, ["reason": reason, "note": note])
    }
}
