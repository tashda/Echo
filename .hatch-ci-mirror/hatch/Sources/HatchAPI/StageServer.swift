import Foundation
import HatchCore
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

/// What the Stage changed, so the Hatch app can refresh the Proposal view.
public struct StageEvent: Equatable, Sendable {
    public enum Kind: String, Sendable { case pick, verdict, pin, note, accept, sendBack, heartbeat }
    public let kind: Kind
    public let ticketId: Int
    public init(kind: Kind, ticketId: Int) { self.kind = kind; self.ticketId = ticketId }
}

/// Called on a server thread after a Stage write succeeded. Hop to the main actor yourself.
public typealias StageEvents = @Sendable (StageEvent) -> Void

struct APIError: Error {
    let status: Int
    let code: String
    let message: String
}

struct HTTPRequest {
    var method = "", target = "", path = "", query: [String: String] = [:]
    var headers: [String: String] = [:]
    var body = Data()
}

/// Local HTTP API for the Stage app (decision S3: Hatch is the only writer). Listens on 127.0.0.1 only and wants a bearer token.
/// Plain HTTP/1.1, one request per connection, JSON bodies.
public final class StageServer: @unchecked Sendable {
    public let store: HatchStore
    public let paths: HatchPaths?
    /// Set before `start()`; the Hatch app uses it to refresh the UI.
    public var events: StageEvents?

    private let requestedPort: UInt16
    private let rememberedKeys: Int
    private var listenFD: Int32 = -1
    private var running = false
    private var acceptDone = DispatchSemaphore(value: 0)
    private let inflight = DispatchGroup()
    private let stateLock = NSLock()
    private let mutationLock = NSLock()
    private var keyCache: [String: (Int, String)] = [:]
    private var keyOrder: [String] = []
    private var _port: UInt16 = 0
    private var _token: String

    /// - Parameters:
    ///   - paths: where to publish `stage-token` and `stage-port`; nil keeps them in memory only (tests).
    ///   - port: 0 picks a free port.
    ///   - rememberedKeys: how many idempotency keys to remember (memory and database).
    public init(store: HatchStore, paths: HatchPaths? = nil, port: UInt16 = 0, token: String? = nil, rememberedKeys: Int = 500) {
        self.store = store
        self.paths = paths
        self.requestedPort = port
        self.rememberedKeys = max(1, rememberedKeys)
        self._token = token ?? StageServer.randomToken()
    }

    deinit { stop() }

    public var port: UInt16 { stateLock.withLock { _port } }
    public var token: String { stateLock.withLock { _token } }
    public var isRunning: Bool { stateLock.withLock { running } }

    static func randomToken() -> String {
        var g = SystemRandomNumberGenerator()
        return (0..<32).map { _ in String(format: "%02x", UInt8.random(in: 0...255, using: &g)) }.joined()
    }

    // MARK: Lifecycle

    /// Binds 127.0.0.1, writes the token (0600) and port files, and starts accepting.
    public func start() throws {
        try stateLock.withLock {
            guard !running else { return }
            try store.ensureAPITables()
            let fd = socket(AF_INET, Self.streamType, 0)
            guard fd >= 0 else { throw APIError(status: 500, code: "socket", message: "Cannot create socket (errno \(errno)).") }
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
            #if canImport(Darwin)
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            #endif
            var addr = sockaddr_in()
            #if canImport(Darwin)
            addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            #endif
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = requestedPort.bigEndian
            addr.sin_addr.s_addr = UInt32(0x7F00_0001).bigEndian
            let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
            guard bound == 0, listen(fd, 128) == 0 else {
                let e = errno; close(fd)
                throw APIError(status: 500, code: "bind", message: "Cannot listen on 127.0.0.1:\(requestedPort) (errno \(e)).")
            }
            var actual = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &actual) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(fd, $0, &len) } }
            _port = UInt16(bigEndian: actual.sin_port)
            if let paths {
                do { try publish(paths) } catch { close(fd); throw error }
            }
            listenFD = fd
            running = true
            acceptDone = DispatchSemaphore(value: 0)
            let done = acceptDone
            let thread = Thread { [weak self] in
                self?.acceptLoop(fd)
                done.signal()
            }
            thread.name = "hatch.stage-server"
            thread.start()
        }
    }

    /// Stops accepting, waits briefly for requests in flight and removes the port file (so clients know Hatch is away).
    public func stop() {
        let wasRunning: Bool = stateLock.withLock {
            let r = running; running = false; return r
        }
        guard wasRunning else { return }
        _ = acceptDone.wait(timeout: .now() + 3)
        stateLock.withLock {
            if listenFD >= 0 { close(listenFD); listenFD = -1 }
        }
        _ = inflight.wait(timeout: .now() + 3)
        if let paths { try? FileManager.default.removeItem(at: paths.portFile) }
    }

    private func publish(_ paths: HatchPaths) throws {
        try paths.createDirectories()
        let fm = FileManager.default
        try? fm.removeItem(at: paths.tokenFile)
        guard fm.createFile(atPath: paths.tokenFile.path, contents: Data(_token.utf8), attributes: [.posixPermissions: 0o600]) else {
            throw APIError(status: 500, code: "token", message: "Cannot write \(paths.tokenFile.path).")
        }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: paths.tokenFile.path)
        try Data(String(_port).utf8).write(to: paths.portFile)
    }

    private static var streamType: Int32 {
        #if os(Linux)
        return Int32(SOCK_STREAM.rawValue)
        #else
        return SOCK_STREAM
        #endif
    }

    private func acceptLoop(_ fd: Int32) {
        while isRunning {
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let n = poll(&pfd, 1, 100)
            if n <= 0 { continue }
            let client = accept(fd, nil, nil)
            if client < 0 { continue }
            var tv = timeval(tv_sec: 5, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            setsockopt(client, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
            #if canImport(Darwin)
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            #endif
            inflight.enter()
            // A thread per connection: an idle connection blocks in recv and must not starve the shared Dispatch pool.
            let worker = Thread { [self] in
                defer { inflight.leave() }
                serve(client)
                close(client)
            }
            worker.name = "hatch.stage-conn"
            worker.start()
        }
    }

    // MARK: HTTP

    private static let maxHeader = 64 * 1024
    private static let maxBody = 2 * 1024 * 1024

    private func serve(_ fd: Int32) {
        let reply: (Int, String, [String: String])
        do {
            let request = try readRequest(fd)
            reply = handle(request)
        } catch let e as APIError {
            reply = (e.status, Self.errorBody(e), [:])
        } catch {
            reply = (400, Self.errorBody(APIError(status: 400, code: "bad_request", message: "Unreadable request.")), [:])
        }
        write(fd, status: reply.0, body: reply.1, extra: reply.2)
    }

    private func readRequest(_ fd: Int32) throws -> HTTPRequest {
        var buffer = [UInt8]()
        var chunk = [UInt8](repeating: 0, count: 8192)
        let terminator: [UInt8] = [13, 10, 13, 10]
        var headEnd: Int?
        while headEnd == nil {
            let n = recv(fd, &chunk, chunk.count, 0)
            if n <= 0 { throw APIError(status: 400, code: "bad_request", message: "Connection closed before the request was complete.") }
            buffer.append(contentsOf: chunk[0..<n])
            if let r = buffer.firstRange(of: terminator) { headEnd = r.lowerBound }
            if buffer.count > Self.maxHeader && headEnd == nil { throw APIError(status: 431, code: "headers_too_large", message: "Request headers are too large.") }
        }
        let head = String(decoding: buffer[0..<headEnd!], as: UTF8.self)
        var lines = head.components(separatedBy: "\r\n")
        let parts = lines.removeFirst().split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        guard parts.count == 3, parts[2].hasPrefix("HTTP/1.") else { throw APIError(status: 400, code: "bad_request", message: "Malformed request line.") }
        var req = HTTPRequest()
        req.method = parts[0].uppercased()
        req.target = parts[1]
        for line in lines {
            guard let colon = line.firstIndex(of: ":") else { continue }
            req.headers[line[..<colon].lowercased()] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        if let te = req.headers["transfer-encoding"], te.lowercased() != "identity" {
            throw APIError(status: 400, code: "bad_request", message: "Chunked bodies are not supported; send Content-Length.")
        }
        let length: Int
        if let cl = req.headers["content-length"] {
            guard let l = Int(cl), l >= 0 else { throw APIError(status: 400, code: "bad_request", message: "Bad Content-Length.") }
            length = l
        } else { length = 0 }
        guard length <= Self.maxBody else { throw APIError(status: 413, code: "too_large", message: "Body is larger than \(Self.maxBody) bytes.") }
        var body = Array(buffer[(headEnd! + 4)...])
        while body.count < length {
            let n = recv(fd, &chunk, chunk.count, 0)
            if n <= 0 { throw APIError(status: 400, code: "bad_request", message: "Body ended early.") }
            body.append(contentsOf: chunk[0..<n])
        }
        req.body = Data(body.prefix(length))
        // Split the target into path and query.
        let pieces = req.target.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        req.path = String(pieces[0])
        if pieces.count == 2 {
            for pair in pieces[1].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let k = String(kv[0]).removingPercentEncoding ?? String(kv[0])
                let v = kv.count == 2 ? (String(kv[1]).removingPercentEncoding ?? String(kv[1])) : ""
                req.query[k] = v
            }
        }
        return req
    }

    private func write(_ fd: Int32, status: Int, body: String, extra: [String: String]) {
        var head = "HTTP/1.1 \(status) \(Self.reason(status))\r\nContent-Type: application/json; charset=utf-8\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n"
        for (k, v) in extra { head += "\(k): \(v)\r\n" }
        head += "\r\n"
        let bytes = Array((head + body).utf8)
        var sent = 0
        while sent < bytes.count {
            #if os(Linux)
            let n = send(fd, Array(bytes[sent...]), bytes.count - sent, Int32(MSG_NOSIGNAL))
            #else
            let n = send(fd, Array(bytes[sent...]), bytes.count - sent, 0)
            #endif
            if n <= 0 { return }
            sent += n
        }
    }

    static func reason(_ status: Int) -> String {
        switch status {
        case 200: "OK"; case 400: "Bad Request"; case 401: "Unauthorized"; case 404: "Not Found"; case 405: "Method Not Allowed"
        case 409: "Conflict"; case 413: "Payload Too Large"; case 422: "Unprocessable Entity"; case 431: "Request Header Fields Too Large"
        default: status >= 500 ? "Internal Server Error" : "Error"
        }
    }

    static func errorBody(_ e: APIError) -> String {
        JSONValue.object(["error": .string(e.message), "code": .string(e.code)]).jsonString()
    }

    // MARK: Routing

    private func authorized(_ req: HTTPRequest) -> Bool {
        guard let header = req.headers["authorization"], header.lowercased().hasPrefix("bearer ") else { return false }
        let given = Array(header.dropFirst(7).trimmingCharacters(in: .whitespaces).utf8)
        let expected = Array(token.utf8)
        var diff = given.count ^ expected.count
        for i in 0..<min(given.count, expected.count) { diff |= Int(given[i] ^ expected[i]) }
        return diff == 0
    }

    func handle(_ req: HTTPRequest) -> (Int, String, [String: String]) {
        do {
            guard authorized(req) else { throw APIError(status: 401, code: "unauthorized", message: "Missing or wrong bearer token.") }
            let (status, json, replay) = try dispatch(req)
            return (status, json.jsonString(), replay ? ["Idempotent-Replay": "true"] : [:])
        } catch let e as APIError {
            return (e.status, Self.errorBody(e), [:])
        } catch let e as WorkflowError {
            return (409, Self.errorBody(APIError(status: 409, code: "illegal_move", message: e.description)), [:])
        } catch let e as StoreError {
            switch e {
            case .notFound: return (404, Self.errorBody(APIError(status: 404, code: "not_found", message: e.description)), [:])
            case .invalid(let m): return (422, Self.errorBody(APIError(status: 422, code: "invalid", message: m)), [:])
            }
        } catch {
            return (500, Self.errorBody(APIError(status: 500, code: "internal", message: "\(error)")), [:])
        }
    }

    private func dispatch(_ req: HTTPRequest) throws -> (Int, JSONValue, Bool) {
        let segments = req.path.split(separator: "/", omittingEmptySubsequences: true).map { String($0).removingPercentEncoding ?? String($0) }
        guard segments.first == "v1" else { throw APIError(status: 404, code: "not_found", message: "Unknown path \(req.path).") }
        let rest = Array(segments.dropFirst())
        let m = req.method

        func need(_ method: String) throws {
            if m != method { throw APIError(status: 405, code: "method_not_allowed", message: "Use \(method) for \(req.path).") }
        }

        if rest == ["health"] { try need("GET"); return (200, ["ok": true, "version": 1], false) }
        if rest.count == 2, rest[0] == "stage", rest[1] == "heartbeat" {
            try need("POST")
            return try mutate(req) { try self.heartbeat(Body(req)) }
        }
        if rest.count == 2, rest[0] == "stage" {
            try need("GET")
            return (200, try stageInfo(ref: rest[1], revision: req.query["revision"]), false)
        }
        if rest.count == 3, rest[0] == "tickets" {
            let ref = rest[1]
            switch rest[2] {
            case "proposal": try need("GET"); return (200, try proposal(ref: ref), false)
            case "pick": try need("POST"); return try mutate(req) { try self.pick(ref, Body(req)) }
            case "verdict": try need("POST"); return try mutate(req) { try self.verdict(ref, Body(req)) }
            case "pin": try need("POST"); return try mutate(req) { try self.pin(ref, Body(req)) }
            case "note": try need("POST"); return try mutate(req) { try self.note(ref, Body(req)) }
            case "accept": try need("POST"); return try mutate(req) { try self.acceptTicket(ref, Body(req)) }
            case "send-back": try need("POST"); return try mutate(req) { try self.sendBack(ref, Body(req)) }
            default: break
            }
        }
        throw APIError(status: 404, code: "not_found", message: "Unknown path \(req.path).")
    }

    /// Runs a write under one lock. With an `Idempotency-Key` a repeated request returns the first answer and changes nothing.
    private func mutate(_ req: HTTPRequest, _ work: () throws -> (JSONValue, StageEvent?)) throws -> (Int, JSONValue, Bool) {
        let key = req.headers["idempotency-key"].flatMap { $0.isEmpty ? nil : $0 }
        if let key, key.utf8.count > 200 { throw APIError(status: 400, code: "bad_request", message: "Idempotency-Key is too long.") }
        mutationLock.lock()
        defer { mutationLock.unlock() }
        if let key {
            let stored = try store.storedResponse(forKey: key)
            if let hit = keyCache[key] ?? stored.map({ ($0.status, $0.body) }) {
                return (hit.0, JSONValue.parse(hit.1), true)
            }
        }
        let (json, event) = try work()
        if let key {
            let body = json.jsonString()
            try store.rememberResponse(key: key, status: 200, body: body, limit: rememberedKeys)
            keyCache[key] = (200, body)
            keyOrder.append(key)
            while keyOrder.count > rememberedKeys { keyCache[keyOrder.removeFirst()] = nil }
        }
        if let event { events?(event) }
        return (200, json, false)
    }

    // MARK: Endpoints

    private func ticket(_ ref: String) throws -> Ticket { try store.resolve(ref) }

    private func summary(_ t: Ticket) -> JSONValue {
        ["id": .int(t.id), "ref": .string(t.displayNumber), "ghNumber": t.ghNumber.map { .int($0) } ?? .null,
         "title": .string(t.title), "type": .string(t.type.rawValue), "status": .string(t.status.rawValue),
         "statusName": .string(t.status.displayName), "turn": .string(t.turn.rawValue), "revision": .int(t.revision)]
    }

    private func iso(_ d: Date) -> JSONValue { .string(ISO8601DateFormatter().string(from: d)) }
    private func opt(_ s: String?) -> JSONValue { s.map { .string($0) } ?? .null }
    private func opt(_ d: Double?) -> JSONValue { d.map { .number($0) } ?? .null }

    private func proposal(ref: String) throws -> JSONValue {
        let t = try ticket(ref)
        let manifest = try store.proposalManifest(ticketId: t.id)
        return [
            "ticket": summary(t),
            "status": .string(t.status.rawValue),
            "revision": .int(t.revision),
            "manifest": opt(manifest),
            "picks": .array(try store.picks(ticketId: t.id).map { ["topic": .string($0.topic), "choice": .string($0.choice), "note": opt($0.note), "at": iso($0.at)] }),
            "verdicts": .array(try store.verdicts(ticketId: t.id).map { ["topic": .string($0.topic), "option": .string($0.option), "verdict": .string($0.verdict), "note": opt($0.note)] }),
            "pins": .array(try store.pins(ticketId: t.id).map {
                ["id": .int($0.id), "option": opt($0.option), "x": opt($0.x), "y": opt($0.y), "scenario": opt($0.scenario), "appearance": opt($0.appearance),
                 "corners": $0.corners.map { .int($0) } ?? .null, "zoom": opt($0.zoom), "text": .string($0.text), "at": iso($0.at)]
            }),
            "revisions": .array(try store.revisions(ticketId: t.id).map {
                ["n": .int($0.n), "summary": .string($0.summary), "added": .array($0.added.map { .string($0) }), "at": iso($0.at)]
            }),
        ]
    }

    /// Only a Proposal or Sketch that is open for judging takes picks, verdicts and pins.
    private func requireOpen(_ t: Ticket) throws {
        guard t.type == .proposal || t.type == .sketch else { throw APIError(status: 409, code: "not_a_proposal", message: "\(t.displayNumber) is a \(t.type.displayName), not a Proposal.") }
        guard t.status == .yourCall || t.status == .revising else {
            throw APIError(status: 409, code: "not_open", message: "\(t.displayNumber) is \(t.status.displayName); it is not open for judging.")
        }
    }

    private func pick(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref); try requireOpen(t)
        let topic = try b.string("topic", max: 200), choice = try b.string("choice", max: 200)
        let note = try b.optionalString("note", max: 10_000)
        try store.setPick(ticketId: t.id, topic: topic, choice: choice, note: note)
        return (["ok": true, "topic": .string(topic), "choice": .string(choice)], StageEvent(kind: .pick, ticketId: t.id))
    }

    private func verdict(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref); try requireOpen(t)
        let topic = try b.string("topic", max: 200), option = try b.string("option", max: 200)
        let verdict = try b.string("verdict", max: 20)
        guard ["pick", "maybe", "no", "none"].contains(verdict) else { throw APIError(status: 400, code: "bad_request", message: "verdict must be pick, maybe, no or none.") }
        if verdict == "none" {
            try store.clearVerdict(ticketId: t.id, topic: topic, option: option)
            return (["ok": true], StageEvent(kind: .verdict, ticketId: t.id))
        }
        let note = try b.optionalString("note", max: 10_000)
        try store.setVerdict(ticketId: t.id, topic: topic, option: option, verdict: verdict, note: note)
        return (["ok": true], StageEvent(kind: .verdict, ticketId: t.id))
    }

    private func pin(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref); try requireOpen(t)
        let text = try b.string("text", max: 10_000)
        let corners = try b.optionalInt("corners")
        let zoom = try b.optionalNumber("zoom")
        if let zoom, zoom <= 0 { throw APIError(status: 400, code: "bad_request", message: "zoom must be positive.") }
        let id = try store.addPin(ticketId: t.id, option: try b.optionalString("option", max: 200), x: try b.optionalNumber("x"), y: try b.optionalNumber("y"),
                                  scenario: try b.optionalString("scenario", max: 200), appearance: try b.optionalString("appearance", max: 200),
                                  corners: corners, zoom: zoom, text: text)
        return (["ok": true, "id": .int(id)], StageEvent(kind: .pin, ticketId: t.id))
    }

    private func note(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref)
        let kindName = try b.string("kind", max: 20)
        guard let kind = ["note": NoteKind.note, "ask": .ask, "instruction": .instruction][kindName] else {
            throw APIError(status: 400, code: "bad_request", message: "kind must be note, ask or instruction.")
        }
        let body = try b.string("body", max: 20_000)
        let added = try store.addNote(t.id, kind: kind, author: "owner", body: body)
        let after = try ticket(ref)
        return (["ok": true, "id": .int(added.id), "status": .string(after.status.rawValue), "sentBack": .bool(after.status != t.status)],
                StageEvent(kind: .note, ticketId: t.id))
    }

    private func acceptTicket(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref)
        var choices: [String: String] = [:]
        if let raw = b.object["choices"], raw != .null {
            guard let o = raw.objectValue else { throw APIError(status: 400, code: "bad_request", message: "choices must be an object of topic: choice.") }
            for (topic, value) in o {
                guard let c = value.stringValue, !c.isEmpty, !topic.isEmpty, c.count <= 200, topic.count <= 200 else {
                    throw APIError(status: 400, code: "bad_request", message: "Every choice must be a non-empty string.")
                }
                choices[topic] = c
            }
        }
        guard t.status == .yourCall else {
            throw APIError(status: 409, code: "illegal_move", message: "\(t.displayNumber) is \(t.status.displayName); only a Proposal in Your call can be accepted.")
        }
        let r = try store.acceptProposal(ticketId: t.id, choices: choices)
        return (["ok": true, "ticket": summary(r.ticket), "decisionId": .int(r.decisionId), "summary": .string(r.summary)], StageEvent(kind: .accept, ticketId: t.id))
    }

    private func sendBack(_ ref: String, _ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(ref)
        let reasonName = try b.string("reason", max: 40)
        guard let reason = SendBackReason(rawValue: reasonName) else {
            throw APIError(status: 400, code: "bad_request", message: "reason must be needs-more-options, change-option or different-direction.")
        }
        let note = try b.string("note", max: 20_000)
        guard t.status == .yourCall else {
            throw APIError(status: 409, code: "illegal_move", message: "\(t.displayNumber) is \(t.status.displayName); only a Proposal in Your call can be sent back.")
        }
        let moved = try store.sendBackProposal(ticketId: t.id, reason: reason, note: note)
        return (["ok": true, "ticket": summary(moved)], StageEvent(kind: .sendBack, ticketId: t.id))
    }

    private static let sessionStates: Set<String> = ["building", "ready", "running", "idle", "crashed", "closed"]

    private func heartbeat(_ b: Body) throws -> (JSONValue, StageEvent?) {
        let t = try ticket(try b.string("ticket", max: 40))
        let revision = try b.int("revision")
        guard revision >= 1 else { throw APIError(status: 400, code: "bad_request", message: "revision must be 1 or more.") }
        let pid = try b.optionalInt("pid")
        let state = try b.string("state", max: 20)
        guard Self.sessionStates.contains(state) else {
            throw APIError(status: 400, code: "bad_request", message: "state must be one of \(Self.sessionStates.sorted().joined(separator: ", ")).")
        }
        try store.upsertStageSession(ticketId: t.id, revision: revision, pid: pid, state: state)
        return (["ok": true, "latestRevision": .int(t.revision), "reload": .bool(t.revision > revision), "status": .string(t.status.rawValue)],
                StageEvent(kind: .heartbeat, ticketId: t.id))
    }

    /// Lets the Stage ask "is there a newer revision?" without sending a heartbeat. `?revision=N` is the one the Stage shows.
    private func stageInfo(ref: String, revision: String?) throws -> JSONValue {
        let t = try ticket(ref)
        var shown: Int?
        if let revision {
            guard let n = Int(revision), n >= 1 else { throw APIError(status: 400, code: "bad_request", message: "revision must be a number.") }
            shown = n
        } else { shown = try store.stageSessions(ticketId: t.id).first?.revision }
        return ["ticket": summary(t), "status": .string(t.status.rawValue), "latestRevision": .int(t.revision),
                "shownRevision": shown.map { .int($0) } ?? .null, "reload": .bool(shown.map { t.revision > $0 } ?? false),
                "open": .bool(t.status == .yourCall || t.status == .revising)]
    }
}

/// A decoded JSON object body with checked accessors; every failure is a 400.
struct Body {
    let object: [String: JSONValue]

    init(_ req: HTTPRequest) throws {
        if req.body.isEmpty { object = [:]; return }
        guard let v = try? JSONDecoder().decode(JSONValue.self, from: req.body), let o = v.objectValue else {
            throw APIError(status: 400, code: "bad_request", message: "Body must be a JSON object.")
        }
        object = o
    }

    private func bad(_ m: String) -> APIError { APIError(status: 400, code: "bad_request", message: m) }

    func string(_ key: String, max: Int) throws -> String {
        guard let v = object[key], v != .null else { throw bad("\(key) is required.") }
        guard let s = v.stringValue else { throw bad("\(key) must be a string.") }
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw bad("\(key) cannot be empty.") }
        guard s.count <= max else { throw bad("\(key) is longer than \(max) characters.") }
        return s
    }

    func optionalString(_ key: String, max: Int) throws -> String? {
        guard let v = object[key], v != .null else { return nil }
        guard let s = v.stringValue else { throw bad("\(key) must be a string.") }
        guard s.count <= max else { throw bad("\(key) is longer than \(max) characters.") }
        return s
    }

    func optionalNumber(_ key: String) throws -> Double? {
        guard let v = object[key], v != .null else { return nil }
        guard let d = v.doubleValue, d.isFinite else { throw bad("\(key) must be a number.") }
        return d
    }

    func optionalInt(_ key: String) throws -> Int? {
        guard let d = try optionalNumber(key) else { return nil }
        guard d == d.rounded(), abs(d) < 1e12 else { throw bad("\(key) must be a whole number.") }
        return Int(d)
    }

    func int(_ key: String) throws -> Int {
        guard let n = try optionalInt(key) else { throw bad("\(key) is required.") }
        return n
    }
}
