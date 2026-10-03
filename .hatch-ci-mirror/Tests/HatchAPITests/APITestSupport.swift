import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import HatchAPI
import HatchCore

/// Shared setup: a real store in a temp directory, a server on a free loopback port, a client pointed at the same directory.
class APITestCase: XCTestCase {
    var home: URL!
    var paths: HatchPaths!
    var store: HatchStore!
    var server: StageServer!
    var projectId = 0
    var events = EventLog()

    final class EventLog: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [StageEvent] = []
        func add(_ e: StageEvent) { lock.withLock { items.append(e) } }
        var all: [StageEvent] { lock.withLock { items } }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        home = FileManager.default.temporaryDirectory.appendingPathComponent("hatch-api-\(UUID().uuidString)", isDirectory: true)
        paths = HatchPaths(home: home)
        try paths.createDirectories()
        store = try HatchStore(path: paths.databasePath)
        projectId = try store.upsertProject(key: "echo", name: "Echo").id
        try restartServer()
    }

    /// A fresh server on a new port with a new token, as after quitting and reopening Hatch.
    func restartServer(rememberedKeys: Int = 500) throws {
        server?.stop()
        server = StageServer(store: store, paths: paths, rememberedKeys: rememberedKeys)
        let log = events
        server.events = { log.add($0) }
        try server.start()
    }

    override func tearDown() {
        server?.stop()
        server = nil
        store = nil
        if let home { try? FileManager.default.removeItem(at: home) }
    }

    /// A Proposal with a gh number, moved along its path to Your call.
    @discardableResult
    func makeProposal(ghNumber: Int = 151, toYourCall: Bool = true, type: TicketType = .proposal) throws -> Ticket {
        let t = try store.createTicket(projectId: projectId, type: type, title: "Toast spacing", ghNumber: ghNumber)
        if toYourCall {
            for (s, a) in [(Status.checking, Actor.agent), (.ready, .hatch), (.preparing, .agent), (.yourCall, .hatch)] {
                do { try store.move(t.id, to: s, actor: a) } catch { try store.move(t.id, to: s, actor: .hatch) }
            }
        }
        return try store.ticket(id: t.id)!
    }

    func client(timeout: TimeInterval = 5) -> StageClient { StageClient(paths: paths, timeout: timeout) }

    /// Raw HTTP call with explicit token and body; returns status and parsed JSON.
    func call(_ method: String, _ path: String, body: JSONValue? = nil, token: String?? = nil, key: String? = nil,
              port: UInt16? = nil, rawBody: String? = nil) throws -> (status: Int, json: JSONValue, headers: [String: String]) {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:\(port ?? server.port)\(path)")!, timeoutInterval: 5)
        req.httpMethod = method
        let tok: String? = token == nil ? server.token : token!
        if let tok { req.setValue("Bearer \(tok)", forHTTPHeaderField: "Authorization") }
        if let key { req.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
        if let rawBody { req.httpBody = Data(rawBody.utf8) } else if let body { req.httpBody = Data(body.jsonString().utf8) }
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var out: (Data?, URLResponse?, Error?) = (nil, nil, nil)
        URLSession.shared.dataTask(with: req) { d, r, e in out = (d, r, e); sem.signal() }.resume()
        guard sem.wait(timeout: .now() + 10) == .success else { throw XCTSkip("request timed out") }
        if let e = out.2 { throw e }
        let http = out.1 as! HTTPURLResponse
        var headers: [String: String] = [:]
        for (k, v) in http.allHeaderFields { headers["\(k)".lowercased()] = "\(v)" }
        return (http.statusCode, JSONValue.parse(String(decoding: out.0 ?? Data(), as: UTF8.self)), headers)
    }
}
