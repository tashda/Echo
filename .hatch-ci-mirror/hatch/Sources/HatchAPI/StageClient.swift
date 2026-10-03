import Foundation
import HatchCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum StageClientError: Error, CustomStringConvertible, Equatable {
    /// Hatch is not running (or not reachable). Picks are kept in the outbox instead.
    case unreachable(String)
    /// Hatch answered with an error; `code` is the machine-readable code from the JSON body.
    case server(status: Int, code: String, message: String)
    public var description: String {
        switch self {
        case .unreachable(let m): return "Hatch is not reachable: \(m)"
        case .server(let s, let c, let m): return "Hatch refused (\(s) \(c)): \(m)"
        }
    }
}

/// Whether a write reached Hatch now or was kept in the outbox for later.
public enum StageDelivery: Equatable, Sendable { case delivered, queued }

/// One line of `outbox.jsonl`.
struct OutboxEntry: Codable {
    var key: String
    var method: String
    var path: String
    var body: JSONValue?
    var at: Double
}

/// The Stage app's side of the local API (decision S3). Reads the token and port from Hatch's support directory on every call,
/// so a restarted Hatch is found again. Writes that cannot be delivered go to a JSON-lines outbox and are replayed in order by `flush()`
/// (decision S7: the Stage never loses a pick). Every write carries an idempotency key, so a replay after a half-delivered batch changes nothing.
/// Calls are synchronous; call them off the main thread.
public final class StageClient: @unchecked Sendable {
    public let paths: HatchPaths
    private let session: URLSession
    private let timeout: TimeInterval
    private let outboxLock = NSLock()
    private let flushLock = NSLock()

    public init(paths: HatchPaths = .current(), timeout: TimeInterval = 5) {
        self.paths = paths
        self.timeout = timeout
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        #if !canImport(FoundationNetworking)
        config.waitsForConnectivity = false
        #endif
        self.session = URLSession(configuration: config)
    }

    deinit { session.invalidateAndCancel() }

    // MARK: Reads (never queued)

    public func health() throws -> JSONValue { try request("GET", "/v1/health", nil, key: nil) }

    /// The Proposal as Hatch has it: ticket, manifest string, revision, picks, verdicts, pins, revisions, status.
    public func proposal(ref: String) throws -> JSONValue { try request("GET", "/v1/tickets/\(Self.enc(ref))/proposal", nil, key: nil) }

    /// Is there a newer revision than the one on screen? (`reload` in the answer.)
    public func stageInfo(ref: String, shownRevision: Int? = nil) throws -> JSONValue {
        let q = shownRevision.map { "?revision=\($0)" } ?? ""
        return try request("GET", "/v1/stage/\(Self.enc(ref))\(q)", nil, key: nil)
    }

    /// Tells Hatch this Stage is alive. Not queued: a late heartbeat is worthless.
    public func heartbeat(ticket: String, revision: Int, pid: Int, state: String) throws -> JSONValue {
        try request("POST", "/v1/stage/heartbeat", ["ticket": .string(ticket), "revision": .int(revision), "pid": .int(pid), "state": .string(state)], key: UUID().uuidString)
    }

    // MARK: Writes that survive Hatch being away

    @discardableResult
    public func pick(ref: String, topic: String, choice: String, note: String? = nil) throws -> StageDelivery {
        var b: [String: JSONValue] = ["topic": .string(topic), "choice": .string(choice)]
        if let note { b["note"] = .string(note) }
        return try send("POST", "/v1/tickets/\(Self.enc(ref))/pick", .object(b))
    }

    @discardableResult
    public func verdict(ref: String, topic: String, option: String, verdict: String, note: String? = nil) throws -> StageDelivery {
        var b: [String: JSONValue] = ["topic": .string(topic), "option": .string(option), "verdict": .string(verdict)]
        if let note { b["note"] = .string(note) }
        return try send("POST", "/v1/tickets/\(Self.enc(ref))/verdict", .object(b))
    }

    @discardableResult
    public func pin(ref: String, text: String, option: String? = nil, x: Double? = nil, y: Double? = nil, scenario: String? = nil,
                    appearance: String? = nil, corners: Int? = nil, zoom: Double? = nil) throws -> StageDelivery {
        var b: [String: JSONValue] = ["text": .string(text)]
        if let option { b["option"] = .string(option) }
        if let x { b["x"] = .number(x) }
        if let y { b["y"] = .number(y) }
        if let scenario { b["scenario"] = .string(scenario) }
        if let appearance { b["appearance"] = .string(appearance) }
        if let corners { b["corners"] = .int(corners) }
        if let zoom { b["zoom"] = .number(zoom) }
        return try send("POST", "/v1/tickets/\(Self.enc(ref))/pin", .object(b))
    }

    /// `kind` is note, ask or instruction. An ask or instruction sends the Proposal back, so it is queued like any other write.
    ///
    /// `screenshot` is a JPEG (or PNG, with `screenshotType: "png"`) of what the owner was looking at (decision H14); Hatch keeps it
    /// as an attachment of the ticket. It must stay under `StageServer.maxScreenshotBytes`, or Hatch refuses it with 413.
    @discardableResult
    public func note(ref: String, kind: String, body: String, screenshot: Data? = nil, screenshotType: String = "jpg") throws -> StageDelivery {
        var b: [String: JSONValue] = ["kind": .string(kind), "body": .string(body)]
        if let screenshot {
            b["screenshot"] = .string(screenshot.base64EncodedString())
            b["screenshotType"] = .string(screenshotType)
        }
        return try send("POST", "/v1/tickets/\(Self.enc(ref))/note", .object(b))
    }

    // MARK: Decisions that need Hatch right now (not queued)

    /// Accept changes the workflow and starts agent work, so it is never held back silently: it throws `unreachable` instead.
    public func accept(ref: String, choices: [String: String]? = nil) throws -> JSONValue {
        var b: [String: JSONValue] = [:]
        if let choices { b["choices"] = .object(choices.mapValues { .string($0) }) }
        return try request("POST", "/v1/tickets/\(Self.enc(ref))/accept", .object(b), key: UUID().uuidString)
    }

    public func sendBack(ref: String, reason: String, note: String) throws -> JSONValue {
        try request("POST", "/v1/tickets/\(Self.enc(ref))/send-back", ["reason": .string(reason), "note": .string(note)], key: UUID().uuidString)
    }

    // MARK: Outbox

    /// Sends now if Hatch is up and nothing is waiting; otherwise appends to the outbox (keeping order) and tries to flush.
    /// A refusal from Hatch (bad input, unknown ticket) throws and is not queued. Only unreachability queues.
    public func send(_ method: String, _ path: String, _ body: JSONValue?) throws -> StageDelivery {
        let entry = OutboxEntry(key: UUID().uuidString, method: method, path: path, body: body, at: Date().timeIntervalSince1970)
        if try outboxEntries().isEmpty {
            do {
                _ = try request(method, path, body, key: entry.key)
                return .delivered
            } catch StageClientError.unreachable {
                try append(entry)
                return .queued
            } catch StageClientError.server(let status, _, _) where Self.isTransient(status) {
                try append(entry)
                return .queued
            }
        }
        try append(entry)
        _ = try? flush()
        return try outboxEntries().contains { $0.key == entry.key } ? .queued : .delivered
    }

    /// Statuses that mean "try again later" rather than "no": a wrong token (Hatch restarted), timeouts, throttling, server faults.
    static func isTransient(_ status: Int) -> Bool { status == 401 || status == 408 || status == 429 || status >= 500 }

    /// Number of requests waiting for Hatch.
    public var pendingCount: Int { (try? outboxEntries().count) ?? 0 }

    /// Delivers waiting requests in order. Stops at the first one that cannot be delivered because Hatch is away or answers 401/5xx.
    /// A request Hatch refuses for good (other 4xx) moves to `outbox-rejected.jsonl` so it is never lost silently.
    /// Returns how many were delivered.
    @discardableResult
    public func flush() throws -> Int {
        flushLock.lock(); defer { flushLock.unlock() }
        var delivered = 0
        while let entry = try outboxEntries().first {
            do {
                _ = try request(entry.method, entry.path, entry.body, key: entry.key)
                try remove(key: entry.key)
                delivered += 1
            } catch StageClientError.server(let status, let code, let message) where !Self.isTransient(status) {
                try reject(entry, status: status, code: code, message: message)
                try remove(key: entry.key)
            } catch StageClientError.server {
                break
            } catch StageClientError.unreachable {
                break
            }
        }
        return delivered
    }

    func outboxEntries() throws -> [OutboxEntry] {
        outboxLock.lock(); defer { outboxLock.unlock() }
        guard let data = try? Data(contentsOf: paths.outboxFile) else { return [] }
        let decoder = JSONDecoder()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { try? decoder.decode(OutboxEntry.self, from: Data($0.utf8)) }
    }

    private func append(_ entry: OutboxEntry) throws {
        outboxLock.lock(); defer { outboxLock.unlock() }
        try appendLine(entry, to: paths.outboxFile)
    }

    private func appendLine<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var line = try encoder.encode(value)
        line.append(10)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: url.path) { _ = FileManager.default.createFile(atPath: url.path, contents: nil) }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        try handle.synchronize()
    }

    private func remove(key: String) throws {
        outboxLock.lock(); defer { outboxLock.unlock() }
        guard let data = try? Data(contentsOf: paths.outboxFile) else { return }
        let decoder = JSONDecoder()
        var kept = [Substring]()
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            if let e = try? decoder.decode(OutboxEntry.self, from: Data(line.utf8)), e.key == key { continue }
            kept.append(line)
        }
        let text = kept.isEmpty ? "" : kept.joined(separator: "\n") + "\n"
        try Data(text.utf8).write(to: paths.outboxFile, options: .atomic)
    }

    private struct Rejected: Encodable { let entry: OutboxEntry; let status: Int; let code: String; let message: String }

    private func reject(_ entry: OutboxEntry, status: Int, code: String, message: String) throws {
        outboxLock.lock(); defer { outboxLock.unlock() }
        try appendLine(Rejected(entry: entry, status: status, code: code, message: message), to: paths.rejectedFile)
    }

    // MARK: HTTP

    static func enc(_ ref: String) -> String {
        ref.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))) ?? ref
    }

    private func request(_ method: String, _ path: String, _ body: JSONValue?, key: String?) throws -> JSONValue {
        guard let token = (try? String(contentsOf: paths.tokenFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty,
              let portText = (try? String(contentsOf: paths.portFile, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines),
              let port = Int(portText), let url = URL(string: "http://127.0.0.1:\(port)\(path)") else {
            throw StageClientError.unreachable("no stage-token or stage-port file; Hatch has not started")
        }
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let key { req.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = Data(body.jsonString().utf8)
        }
        let box = ResultBox()
        let done = DispatchSemaphore(value: 0)
        let task = session.dataTask(with: req) { data, response, error in
            box.set(data: data, response: response as? HTTPURLResponse, error: error)
            done.signal()
        }
        task.resume()
        if done.wait(timeout: .now() + timeout + 2) == .timedOut {
            task.cancel()
            throw StageClientError.unreachable("timed out")
        }
        let (data, response, error) = box.get()
        if let error { throw StageClientError.unreachable(error.localizedDescription) }
        guard let response else { throw StageClientError.unreachable("no response") }
        let json = data.map { JSONValue.parse(String(decoding: $0, as: UTF8.self)) } ?? .null
        guard (200..<300).contains(response.statusCode) else {
            throw StageClientError.server(status: response.statusCode, code: json["code"]?.stringValue ?? "error",
                                          message: json["error"]?.stringValue ?? "HTTP \(response.statusCode)")
        }
        return json
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?, response: HTTPURLResponse?, error: Error?
    func set(data: Data?, response: HTTPURLResponse?, error: Error?) { lock.withLock { self.data = data; self.response = response; self.error = error } }
    func get() -> (Data?, HTTPURLResponse?, Error?) { lock.withLock { (data, response, error) } }
}
