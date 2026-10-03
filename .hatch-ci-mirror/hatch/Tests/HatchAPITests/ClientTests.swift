import XCTest
import Foundation
import HatchCore
@testable import HatchAPI

final class ClientTests: APITestCase {
    var stageHome: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
    }

    func testPathsOverrideAndDefaults() {
        let p = HatchPaths.current(environment: ["HATCH_HOME": "/tmp/h"])
        XCTAssertEqual(p.home.path, "/tmp/h")
        XCTAssertEqual(p.databasePath, "/tmp/h/hatch.sqlite")
        XCTAssertEqual(p.tokenFile.path, "/tmp/h/stage-token")
        XCTAssertEqual(p.portFile.path, "/tmp/h/stage-port")
        XCTAssertEqual(p.outboxFile.path, "/tmp/h/stage/outbox.jsonl")
        let d = HatchPaths.current(environment: [:])
        #if os(macOS)
        XCTAssertTrue(d.home.path.hasSuffix("Library/Application Support/Hatch"))
        #else
        XCTAssertTrue(d.home.path.hasSuffix(".local/share/hatch"))
        #endif
    }

    func testClientEndpoints() throws {
        let t = try makeProposal()
        let c = client()
        XCTAssertEqual(try c.health()["ok"], .bool(true))
        XCTAssertEqual(try c.pick(ref: "#151", topic: "spacing", choice: "B", note: "n"), .delivered)
        XCTAssertEqual(try c.verdict(ref: "151", topic: "spacing", option: "A", verdict: "maybe"), .delivered)
        XCTAssertEqual(try c.pin(ref: "151", text: "look", option: "A", x: 0.1, y: 0.2, scenario: "Rest", appearance: "light", corners: 10, zoom: 1.5), .delivered)
        XCTAssertEqual(try c.note(ref: "151", kind: "note", body: "hi"), .delivered)
        XCTAssertEqual(try c.heartbeat(ticket: "151", revision: 1, pid: 1, state: "running")["ok"], .bool(true))
        let p = try c.proposal(ref: "151")
        XCTAssertEqual(p["picks"]?.arrayValue?.count, 1)
        XCTAssertEqual(p["pins"]?.arrayValue?.count, 1)
        XCTAssertEqual(try c.stageInfo(ref: "151", shownRevision: 1)["reload"], .bool(false))
        let accepted = try c.accept(ref: "151", choices: ["icon": "A"])
        XCTAssertEqual(accepted["ticket"]?["status"]?.stringValue, "accepted")
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .accepted)
        XCTAssertEqual(c.pendingCount, 0)
    }

    func testClientNoteWithScreenshotAndQueuedWhileHatchIsAway() throws {
        let t = try makeProposal()
        let c = client()
        let picture = Data(repeating: 7, count: 500)
        XCTAssertEqual(try c.note(ref: "151", kind: "note", body: "look", screenshot: picture), .delivered)
        XCTAssertEqual(try store.attachments(ticketId: t.id).count, 1)
        server.stop()
        XCTAssertEqual(try c.note(ref: "151", kind: "note", body: "later", screenshot: picture), .queued)
        XCTAssertEqual(c.pendingCount, 1)
        try restartServer()
        XCTAssertEqual(try c.flush(), 1)
        XCTAssertEqual(try store.attachments(ticketId: t.id).count, 2)
    }

    func testClearingAVerdictFromTheClient() throws {
        let t = try makeProposal()
        let c = client()
        _ = try c.verdict(ref: "151", topic: "which", option: "A", verdict: "maybe")
        XCTAssertEqual(try store.verdicts(ticketId: t.id).count, 1)
        _ = try c.verdict(ref: "151", topic: "which", option: "A", verdict: "none")
        XCTAssertTrue(try store.verdicts(ticketId: t.id).isEmpty)
    }

    func testClientSendBack() throws {
        let t = try makeProposal()
        _ = try client().sendBack(ref: "151", reason: "change-option", note: "Option B is too loud")
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
    }

    func testClientSurfacesServerErrorsAndDoesNotQueueThem() throws {
        try makeProposal()
        let c = client()
        XCTAssertThrowsError(try c.pick(ref: "999", topic: "a", choice: "b")) { e in
            guard case StageClientError.server(let status, let code, _) = e else { return XCTFail("\(e)") }
            XCTAssertEqual(status, 404)
            XCTAssertEqual(code, "not_found")
        }
        XCTAssertThrowsError(try c.verdict(ref: "151", topic: "a", option: "b", verdict: "adore"))
        XCTAssertEqual(c.pendingCount, 0)
    }

    func testServerDownQueuesThenFlushDeliversOnceInOrder() throws {
        let t = try makeProposal()
        server.stop()
        let c = client(timeout: 2)
        XCTAssertEqual(try c.pick(ref: "151", topic: "t1", choice: "first"), .queued)
        XCTAssertEqual(try c.pick(ref: "151", topic: "t2", choice: "second"), .queued)
        XCTAssertEqual(try c.note(ref: "151", kind: "note", body: "third"), .queued)
        XCTAssertEqual(try c.verdict(ref: "151", topic: "t1", option: "A", verdict: "pick"), .queued)
        XCTAssertEqual(c.pendingCount, 4)
        XCTAssertTrue(try store.picks(ticketId: t.id).isEmpty)
        XCTAssertEqual(try c.flush(), 0)
        XCTAssertEqual(c.pendingCount, 4)

        // The outbox is plain JSON lines in the Stage directory.
        let lines = try String(contentsOf: paths.outboxFile, encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 4)

        // Hatch comes back, on a new port and with a new token.
        try restartServer()
        XCTAssertEqual(try c.flush(), 4)
        XCTAssertEqual(c.pendingCount, 0)
        XCTAssertEqual(try store.picks(ticketId: t.id).map(\.choice), ["first", "second"])
        XCTAssertEqual(try store.verdicts(ticketId: t.id).count, 1)
        XCTAssertEqual(try store.notes(ticketId: t.id).filter { $0.body == "third" }.count, 1)
        // Order: the events table records picks before the note before the verdict.
        let kinds = events.all.map(\.kind)
        XCTAssertEqual(kinds, [.pick, .pick, .note, .verdict])
        // A second flush has nothing to do.
        XCTAssertEqual(try c.flush(), 0)
    }

    func testQueueSurvivesNewClientInstance() throws {
        let t = try makeProposal()
        server.stop()
        XCTAssertEqual(try client(timeout: 2).pick(ref: "151", topic: "x", choice: "kept"), .queued)
        try restartServer()
        let fresh = client()
        XCTAssertEqual(fresh.pendingCount, 1)
        XCTAssertEqual(try fresh.flush(), 1)
        XCTAssertEqual(try store.picks(ticketId: t.id).first?.choice, "kept")
    }

    func testNewWriteBehindAQueueKeepsOrder() throws {
        let t = try makeProposal()
        server.stop()
        let c = client(timeout: 2)
        _ = try c.pick(ref: "151", topic: "same", choice: "old")
        try restartServer()
        // The server is back; the next write flushes the old one first so "new" wins.
        XCTAssertEqual(try c.pick(ref: "151", topic: "same", choice: "new"), .delivered)
        XCTAssertEqual(try store.picks(ticketId: t.id).map(\.choice), ["new"])
        XCTAssertEqual(c.pendingCount, 0)
    }

    func testReplayedKeyDoesNotDuplicate() throws {
        let t = try makeProposal()
        let c = client()
        // Simulate "delivered but the Stage crashed before removing it from the outbox".
        let entry = OutboxEntry(key: "replay-1", method: "POST", path: "/v1/tickets/151/note", body: ["kind": "note", "body": "just once"], at: 0)
        try FileManager.default.createDirectory(at: paths.stageHome, withIntermediateDirectories: true)
        var line = try JSONEncoder().encode(entry); line.append(10)
        try line.write(to: paths.outboxFile)
        _ = try call("POST", entry.path, body: entry.body, key: entry.key)
        XCTAssertEqual(try c.flush(), 1)
        XCTAssertEqual(try store.notes(ticketId: t.id).filter { $0.body == "just once" }.count, 1)
        XCTAssertEqual(c.pendingCount, 0)
    }

    func testRefusedEntryMovesToRejectedFileAndDoesNotBlockTheRest() throws {
        let t = try makeProposal()
        server.stop()
        let c = client(timeout: 2)
        _ = try c.pick(ref: "777", topic: "a", choice: "b")
        _ = try c.pick(ref: "151", topic: "good", choice: "yes")
        try restartServer()
        XCTAssertEqual(try c.flush(), 1)
        XCTAssertEqual(c.pendingCount, 0)
        XCTAssertEqual(try store.picks(ticketId: t.id).map(\.topic), ["good"])
        let rejected = try String(contentsOf: paths.rejectedFile, encoding: .utf8)
        XCTAssertTrue(rejected.contains("777"))
    }

    func testStaleTokenIsRetriedLater() throws {
        let t = try makeProposal()
        // The Stage has a token from a previous Hatch run.
        try Data("stale".utf8).write(to: paths.tokenFile)
        let c = client()
        XCTAssertEqual(try c.pick(ref: "151", topic: "a", choice: "b"), .queued)
        try Data(server.token.utf8).write(to: paths.tokenFile)
        XCTAssertEqual(try c.flush(), 1)
        XCTAssertEqual(try store.picks(ticketId: t.id).count, 1)
    }

    func testAcceptWhileHatchIsAwayThrowsInsteadOfQueueing() throws {
        try makeProposal()
        server.stop()
        let c = client(timeout: 2)
        XCTAssertThrowsError(try c.accept(ref: "151")) { e in
            guard case StageClientError.unreachable = e else { return XCTFail("\(e)") }
        }
        XCTAssertEqual(c.pendingCount, 0)
    }

    func testNoFilesMeansUnreachable() throws {
        let empty = HatchPaths(home: home.appendingPathComponent("elsewhere"))
        let c = StageClient(paths: empty, timeout: 1)
        XCTAssertThrowsError(try c.health())
        XCTAssertEqual(try c.pick(ref: "1", topic: "a", choice: "b"), .queued)
        XCTAssertEqual(c.pendingCount, 1)
    }
}
