import XCTest
import Foundation
import HatchCore
@testable import HatchAPI

final class ServerTests: APITestCase {
    func testHealthNeedsToken() throws {
        let ok = try call("GET", "/v1/health")
        XCTAssertEqual(ok.status, 200)
        XCTAssertEqual(ok.json["ok"], .bool(true))
    }

    func testMissingAndWrongTokenAre401() throws {
        let none = try call("GET", "/v1/health", token: .some(nil))
        XCTAssertEqual(none.status, 401)
        XCTAssertEqual(none.json["code"]?.stringValue, "unauthorized")
        let wrong = try call("GET", "/v1/health", token: .some("nope"))
        XCTAssertEqual(wrong.status, 401)
        let t = try makeProposal()
        let post = try call("POST", "/v1/tickets/151/pick", body: ["topic": "a", "choice": "b"], token: .some("nope"))
        XCTAssertEqual(post.status, 401)
        XCTAssertTrue(try store.picks(ticketId: t.id).isEmpty)
    }

    func testTokenAndPortFilesArePublished() throws {
        let token = try String(contentsOf: paths.tokenFile, encoding: .utf8)
        XCTAssertEqual(token, server.token)
        XCTAssertEqual(token.count, 64)
        XCTAssertEqual(try String(contentsOf: paths.portFile, encoding: .utf8), String(server.port))
        let attrs = try FileManager.default.attributesOfItem(atPath: paths.tokenFile.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
    }

    func testStopRemovesPortFileAndRefusesConnections() throws {
        let port = server.port
        server.stop()
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.portFile.path))
        XCTAssertThrowsError(try call("GET", "/v1/health", port: port))
    }

    func testGetProposalReturnsEverything() throws {
        let t = try makeProposal()
        try store.saveProposal(ticketId: t.id, manifestJSON: "{\"topics\":[\"spacing\"]}")
        try store.setPick(ticketId: t.id, topic: "spacing", choice: "B", note: "tighter")
        try store.setVerdict(ticketId: t.id, topic: "spacing", option: "A", verdict: "maybe")
        try store.addPin(ticketId: t.id, option: "A", x: 0.5, y: 0.25, scenario: "Rest", appearance: "dark", corners: 10, zoom: 1, text: "gap")
        let r = try call("GET", "/v1/tickets/151/proposal")
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(r.json["ticket"]?["title"]?.stringValue, "Toast spacing")
        XCTAssertEqual(r.json["status"]?.stringValue, "your-call")
        XCTAssertEqual(r.json["manifest"]?.stringValue, "{\"topics\":[\"spacing\"]}")
        XCTAssertEqual(r.json["revision"]?.doubleValue, 1)
        XCTAssertEqual(r.json["picks"]?.arrayValue?.count, 1)
        XCTAssertEqual(r.json["picks"]?.arrayValue?.first?["note"]?.stringValue, "tighter")
        XCTAssertEqual(r.json["verdicts"]?.arrayValue?.first?["verdict"]?.stringValue, "maybe")
        XCTAssertEqual(r.json["pins"]?.arrayValue?.first?["scenario"]?.stringValue, "Rest")
        XCTAssertEqual(r.json["revisions"]?.arrayValue?.count, 0)
    }

    func testProposalWithoutManifestHasNullManifest() throws {
        try makeProposal()
        let r = try call("GET", "/v1/tickets/%23151/proposal")
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(r.json["manifest"], .null)
    }

    func testUnknownTicketIs404() throws {
        let r = try call("GET", "/v1/tickets/999/proposal")
        XCTAssertEqual(r.status, 404)
        XCTAssertEqual(r.json["code"]?.stringValue, "not_found")
        XCTAssertNotNil(r.json["error"]?.stringValue)
        XCTAssertEqual(try call("POST", "/v1/tickets/999/pick", body: ["topic": "a", "choice": "b"]).status, 404)
        XCTAssertEqual(try call("GET", "/v1/stage/999").status, 404)
    }

    func testUnknownPathAndWrongMethod() throws {
        XCTAssertEqual(try call("GET", "/v2/health").status, 404)
        XCTAssertEqual(try call("GET", "/v1/nothing").status, 404)
        try makeProposal()
        XCTAssertEqual(try call("GET", "/v1/tickets/151/pick").status, 405)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/proposal", body: [:]).status, 405)
    }

    func testPick() throws {
        let t = try makeProposal()
        let r = try call("POST", "/v1/tickets/151/pick", body: ["topic": "spacing", "choice": "B", "note": "why"])
        XCTAssertEqual(r.status, 200)
        let picks = try store.picks(ticketId: t.id)
        XCTAssertEqual(picks.count, 1)
        XCTAssertEqual(picks[0].choice, "B")
        XCTAssertEqual(picks[0].note, "why")
        // Picking again changes the choice, not the count.
        _ = try call("POST", "/v1/tickets/151/pick", body: ["topic": "spacing", "choice": "C"])
        XCTAssertEqual(try store.picks(ticketId: t.id).map(\.choice), ["C"])
        XCTAssertTrue(events.all.contains(StageEvent(kind: .pick, ticketId: t.id)))
    }

    func testPickValidation() throws {
        let t = try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pick", body: ["choice": "B"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pick", body: ["topic": "  ", "choice": "B"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pick", body: ["topic": 4, "choice": "B"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pick", rawBody: "{not json").status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pick", rawBody: "[1,2]").status, 400)
        let long = String(repeating: "x", count: 201)
        let r = try call("POST", "/v1/tickets/151/pick", body: ["topic": .string(long), "choice": "B"])
        XCTAssertEqual(r.status, 400)
        XCTAssertEqual(r.json["code"]?.stringValue, "bad_request")
        XCTAssertTrue(try store.picks(ticketId: t.id).isEmpty)
    }

    func testPickOnTicketNotOpenIs409() throws {
        let t = try makeProposal(toYourCall: false)
        let r = try call("POST", "/v1/tickets/151/pick", body: ["topic": "a", "choice": "b"])
        XCTAssertEqual(r.status, 409)
        XCTAssertEqual(r.json["code"]?.stringValue, "not_open")
        XCTAssertTrue(try store.picks(ticketId: t.id).isEmpty)
        let bug = try makeProposal(ghNumber: 152, toYourCall: false, type: .bug)
        XCTAssertEqual(try call("POST", "/v1/tickets/\(bug.ghNumber!)/pick", body: ["topic": "a", "choice": "b"]).json["code"]?.stringValue, "not_a_proposal")
    }

    func testVerdict() throws {
        let t = try makeProposal()
        let r = try call("POST", "/v1/tickets/151/verdict", body: ["topic": "spacing", "option": "A", "verdict": "no", "note": "too tight"])
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(try store.verdicts(ticketId: t.id).first?.verdict, "no")
        XCTAssertEqual(try call("POST", "/v1/tickets/151/verdict", body: ["topic": "spacing", "option": "A", "verdict": "love"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/verdict", body: ["topic": "spacing", "option": "A", "verdict": "none"]).status, 200)
        XCTAssertTrue(try store.verdicts(ticketId: t.id).isEmpty)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/verdict", body: ["topic": "spacing", "verdict": "no"]).status, 400)
    }

    func testPin() throws {
        let t = try makeProposal()
        let r = try call("POST", "/v1/tickets/151/pin", body: ["option": "B", "x": .number(0.4), "y": .number(0.6), "scenario": "Hover", "appearance": "dark", "corners": 26, "zoom": 2, "text": "icon too close"])
        XCTAssertEqual(r.status, 200)
        XCTAssertNotNil(r.json["id"]?.doubleValue)
        let pin = try XCTUnwrap(store.pins(ticketId: t.id).first)
        XCTAssertEqual(pin.scenario, "Hover")
        XCTAssertEqual(pin.corners, 26)
        XCTAssertEqual(pin.zoom, 2)
        XCTAssertEqual(pin.x, 0.4)
        // A pin needs only text.
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pin", body: ["text": "general"]).status, 200)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pin", body: ["x": 1]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pin", body: ["text": "z", "zoom": -1]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pin", body: ["text": "z", "corners": .number(1.5)]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/pin", body: ["text": "z", "x": "left"]).status, 400)
        XCTAssertEqual(try store.pins(ticketId: t.id).count, 2)
    }

    func testPlainNoteKeepsStatusAndAskSendsBack() throws {
        let t = try makeProposal()
        let plain = try call("POST", "/v1/tickets/151/note", body: ["kind": "note", "body": "FYI"])
        XCTAssertEqual(plain.status, 200)
        XCTAssertEqual(plain.json["sentBack"], .bool(false))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .yourCall)
        let ask = try call("POST", "/v1/tickets/151/note", body: ["kind": "ask", "body": "Why 8pt?"])
        XCTAssertEqual(ask.status, 200)
        XCTAssertEqual(ask.json["sentBack"], .bool(true))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
    }

    func testInstructionSendsBackAndBadKindRejected() throws {
        let t = try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/tickets/151/note", body: ["kind": "shout", "body": "x"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/note", body: ["kind": "note", "body": ""]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/note", body: ["kind": "instruction", "body": "Add a third option"]).status, 200)
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
    }

    func testAcceptMovesToAcceptedAndRecordsDecision() throws {
        let t = try makeProposal()
        _ = try call("POST", "/v1/tickets/151/pick", body: ["topic": "spacing", "choice": "B"])
        let r = try call("POST", "/v1/tickets/151/accept", body: ["choices": ["icon": "A"]])
        XCTAssertEqual(r.status, 200, "\(r.json)")
        XCTAssertEqual(r.json["ticket"]?["status"]?.stringValue, "accepted")
        let summary = try XCTUnwrap(r.json["summary"]?.stringValue)
        XCTAssertTrue(summary.contains("spacing = B"))
        XCTAssertTrue(summary.contains("icon = A"))
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .accepted)
        XCTAssertEqual(try store.picks(ticketId: t.id).count, 2)
    }

    func testAcceptTwiceAndAcceptWhenNotYourCallIs409() throws {
        try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/tickets/151/accept", body: [:]).status, 200)
        let again = try call("POST", "/v1/tickets/151/accept", body: [:])
        XCTAssertEqual(again.status, 409)
        XCTAssertEqual(again.json["code"]?.stringValue, "illegal_move")
        XCTAssertFalse(again.json["error"]?.stringValue?.isEmpty ?? true)
        try makeProposal(ghNumber: 160, toYourCall: false)
        XCTAssertEqual(try call("POST", "/v1/tickets/160/accept", body: [:]).status, 409)
    }

    func testFailedAcceptLeavesPicksUntouched() throws {
        let t = try makeProposal(ghNumber: 161, toYourCall: false)
        let r = try call("POST", "/v1/tickets/161/accept", body: ["choices": ["spacing": "B"]])
        XCTAssertEqual(r.status, 409)
        XCTAssertTrue(try store.picks(ticketId: t.id).isEmpty)
    }

    func testAcceptValidatesChoices() throws {
        try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/tickets/151/accept", body: ["choices": ["a": 3]]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/accept", body: ["choices": "A"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/accept", body: ["choices": ["a": ""]]).status, 400)
    }

    func testSendBack() throws {
        let t = try makeProposal()
        for reason in ["needs-more-options"] {
            let r = try call("POST", "/v1/tickets/151/send-back", body: ["reason": .string(reason), "note": "Try a denser layout"])
            XCTAssertEqual(r.status, 200, "\(r.json)")
            XCTAssertEqual(r.json["ticket"]?["status"]?.stringValue, "revising")
        }
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .revising)
        let notes = try store.notes(ticketId: t.id)
        XCTAssertTrue(notes.contains { $0.kind == .instruction && $0.body.contains("denser") })
    }

    func testSendBackValidation() throws {
        let t = try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/tickets/151/send-back", body: ["reason": "needs-more-options"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/send-back", body: ["reason": "needs-more-options", "note": "   "]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/send-back", body: ["reason": "bored", "note": "x"]).status, 400)
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .yourCall)
        // Sending back twice is an illegal move.
        XCTAssertEqual(try call("POST", "/v1/tickets/151/send-back", body: ["reason": "change-option", "note": "x"]).status, 200)
        XCTAssertEqual(try call("POST", "/v1/tickets/151/send-back", body: ["reason": "different-direction", "note": "x"]).status, 409)
    }

    func testHeartbeatUpsertsSession() throws {
        let t = try makeProposal()
        let body: JSONValue = ["ticket": "#151", "revision": 1, "pid": 4242, "state": "running"]
        let r = try call("POST", "/v1/stage/heartbeat", body: body)
        XCTAssertEqual(r.status, 200)
        XCTAssertEqual(r.json["reload"], .bool(false))
        _ = try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 1, "pid": 4242, "state": "idle"])
        let sessions = try store.stageSessions(ticketId: t.id)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].state, "idle")
        XCTAssertEqual(sessions[0].pid, 4242)
        _ = try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 1, "pid": 99, "state": "running"])
        XCTAssertEqual(try store.stageSessions(ticketId: t.id).count, 2)
    }

    func testHeartbeatValidation() throws {
        try makeProposal()
        XCTAssertEqual(try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 0, "pid": 1, "state": "running"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 1, "pid": 1, "state": "dancing"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/stage/heartbeat", body: ["revision": 1, "state": "idle"]).status, 400)
        XCTAssertEqual(try call("POST", "/v1/stage/heartbeat", body: ["ticket": "404", "revision": 1, "state": "idle"]).status, 404)
    }

    func testReloadDetection() throws {
        let t = try makeProposal()
        var info = try call("GET", "/v1/stage/151?revision=1")
        XCTAssertEqual(info.json["reload"], .bool(false))
        XCTAssertEqual(info.json["latestRevision"]?.doubleValue, 1)
        // The agent hands in revision 2 after a send back.
        try store.move(t.id, to: .revising, actor: .owner)
        try store.recordRevision(ticketId: t.id, summary: "Added option D", added: ["D"])
        info = try call("GET", "/v1/stage/151?revision=1")
        XCTAssertEqual(info.json["reload"], .bool(true))
        XCTAssertEqual(info.json["latestRevision"]?.doubleValue, 2)
        XCTAssertEqual(try call("GET", "/v1/stage/151?revision=2").json["reload"], .bool(false))
        XCTAssertEqual(try call("GET", "/v1/stage/151?revision=abc").status, 400)
        // Without a query the revision comes from the Stage's last heartbeat.
        _ = try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 1, "pid": 7, "state": "running"])
        let hb = try call("POST", "/v1/stage/heartbeat", body: ["ticket": "151", "revision": 1, "pid": 7, "state": "running"])
        XCTAssertEqual(hb.json["reload"], .bool(true))
        XCTAssertEqual(try call("GET", "/v1/stage/151").json["reload"], .bool(true))
        let revs = try call("GET", "/v1/tickets/151/proposal").json["revisions"]?.arrayValue
        XCTAssertEqual(revs?.first?["summary"]?.stringValue, "Added option D")
    }

    func testIdempotencyKeyReplaysWithoutDuplicating() throws {
        let t = try makeProposal()
        let body: JSONValue = ["kind": "note", "body": "once only"]
        let a = try call("POST", "/v1/tickets/151/note", body: body, key: "k-1")
        let b = try call("POST", "/v1/tickets/151/note", body: body, key: "k-1")
        XCTAssertEqual(a.status, 200)
        XCTAssertEqual(b.status, 200)
        XCTAssertEqual(a.json, b.json)
        XCTAssertEqual(b.headers["idempotent-replay"], "true")
        XCTAssertNil(a.headers["idempotent-replay"])
        XCTAssertEqual(try store.notes(ticketId: t.id).filter { $0.body == "once only" }.count, 1)
        _ = try call("POST", "/v1/tickets/151/note", body: body, key: "k-2")
        XCTAssertEqual(try store.notes(ticketId: t.id).filter { $0.body == "once only" }.count, 2)
    }

    func testIdempotencyKeySurvivesServerRestart() throws {
        let t = try makeProposal()
        _ = try call("POST", "/v1/tickets/151/note", body: ["kind": "note", "body": "persisted"], key: "k-9")
        server.stop()
        try restartServer()
        let r = try call("POST", "/v1/tickets/151/note", body: ["kind": "note", "body": "persisted"], key: "k-9")
        XCTAssertEqual(r.headers["idempotent-replay"], "true")
        XCTAssertEqual(try store.notes(ticketId: t.id).filter { $0.body == "persisted" }.count, 1)
    }

    func testOldKeysAreForgottenBeyondTheLimit() throws {
        let t = try makeProposal()
        try restartServer(rememberedKeys: 3)
        for i in 0..<5 { _ = try call("POST", "/v1/tickets/151/note", body: ["kind": "note", "body": .string("n\(i)")], key: "key-\(i)") }
        XCTAssertEqual(try store.notes(ticketId: t.id).count, 5)
        XCTAssertNil(try store.storedResponse(forKey: "key-0"))
        XCTAssertNotNil(try store.storedResponse(forKey: "key-4"))
    }

    func testTwentyParallelPicks() throws {
        let t = try makeProposal()
        let group = DispatchGroup()
        let failures = EventLog()
        let lock = NSLock()
        nonisolated(unsafe) var bad = 0
        for i in 0..<20 {
            group.enter()
            // Real threads: blocked Dispatch workers would starve URLSession's own callbacks.
            Thread.detachNewThread {
                defer { group.leave() }
                do {
                    let r = try self.call("POST", "/v1/tickets/151/pick", body: ["topic": .string("topic-\(i)"), "choice": .string("c\(i)")])
                    if r.status != 200 { lock.withLock { bad += 1 } }
                } catch { lock.withLock { bad += 1 } }
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
        _ = failures
        XCTAssertEqual(bad, 0)
        let picks = try store.picks(ticketId: t.id)
        XCTAssertEqual(picks.count, 20)
        XCTAssertEqual(Set(picks.map(\.choice)).count, 20)
    }

    func testTwentyParallelPicksOnOneTopicLeaveOneRow() throws {
        let t = try makeProposal()
        let group = DispatchGroup()
        for i in 0..<20 {
            group.enter()
            // Real threads: blocked Dispatch workers would starve URLSession's own callbacks.
            Thread.detachNewThread {
                defer { group.leave() }
                _ = try? self.call("POST", "/v1/tickets/151/pick", body: ["topic": "same", "choice": .string("c\(i)")])
            }
        }
        XCTAssertEqual(group.wait(timeout: .now() + 30), .success)
        XCTAssertEqual(try store.picks(ticketId: t.id).count, 1)
    }

    func testOversizedBodyIs413() throws {
        try makeProposal()
        let huge = String(repeating: "a", count: 2_100_000)
        let r = try call("POST", "/v1/tickets/151/note", rawBody: "{\"kind\":\"note\",\"body\":\"\(huge)\"}")
        XCTAssertEqual(r.status, 413)
    }
}
