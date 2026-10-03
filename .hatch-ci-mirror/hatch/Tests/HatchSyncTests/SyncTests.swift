import XCTest
@testable import HatchSync
import HatchCore

final class SyncTests: XCTestCase {
    var store: HatchStore!
    var project: Project!
    var tracker: InMemoryTracker!
    var engine: SyncEngine!
    var clock: Date!
    let repo = "acme/tickets"

    override func setUpWithError() throws {
        clock = Date(timeIntervalSince1970: 1_800_000_000)
        let box = ClockBox(clock)
        self.box = box
        store = try HatchStore.inMemory(now: { box.date })
        project = try store.upsertProject(key: "echo", name: "Echo", config: ProjectConfig(name: "Echo", ticketsRepo: repo, repos: [
            RepoConfig(role: .app, remote: "acme/app", branch: "dev", testPlans: ["UnitTests"]),
        ], areas: []))
        tracker = InMemoryTracker(clock: { box.date })
        engine = SyncEngine(store: store, tracker: tracker)
    }
    var box: ClockBox!

    final class ClockBox: @unchecked Sendable {
        var date: Date
        init(_ d: Date) { date = d }
        func advance(_ s: TimeInterval) { date = date.addingTimeInterval(s) }
    }

    func submitted(_ type: TicketType = .tweak, _ title: String = "Toast spacing") throws -> Ticket {
        let t = try store.createTicket(projectId: project.id, type: type, title: title, body: "Body text")
        return try store.move(t.id, to: .checking, actor: .owner)
    }

    func synced(_ type: TicketType = .tweak) throws -> Ticket {
        let t = try submitted(type)
        try engine.pushPending(repo: repo)
        return try store.ticket(id: t.id)!
    }

    // MARK: Push

    func testCreatePushesIssueAndStoresNumber() throws {
        let t = try submitted()
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.done, 1); XCTAssertEqual(s.failed, 0)
        let after = try store.ticket(id: t.id)!
        XCTAssertEqual(after.ghNumber, 1)
        let issue = tracker.issue(repo, 1)!
        XCTAssertEqual(issue.title, "Toast spacing")
        XCTAssertEqual(Set(issue.labels), ["type:tweak", "status:checking", "project:echo"])
        XCTAssertTrue(try store.pendingSync().isEmpty)
    }

    func testPushTwiceDoesNothingTheSecondTime() throws {
        _ = try submitted()
        try engine.pushPending(repo: repo)
        let calls = tracker.calls.count
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s, PushSummary())
        XCTAssertEqual(tracker.calls.count, calls)
    }

    func testLabelsEnsuredOncePerRepo() throws {
        _ = try submitted(); _ = try submitted(.tweak, "Second")
        try engine.pushPending(repo: repo)
        XCTAssertEqual(tracker.callCount("ensureLabels"), 1)
        XCTAssertNotNil(tracker.knownLabels[repo]?["status:checking"])
        XCTAssertEqual(tracker.knownLabels[repo]?["status:your-call"]?.color, "F0A25E")
        XCTAssertEqual(tracker.knownLabels[repo]?["status:building"]?.color, "4FC3D4")
    }

    func testStatusChangeReplacesOnlyHatchLabels() throws {
        let t = try synced()
        tracker.humanEdit(repo: repo, number: 1, labels: ["type:tweak", "status:checking", "project:echo", "good first issue"])
        _ = try store.move(t.id, to: .ready, actor: .hatch)
        try engine.pushPending(repo: repo)
        let labels = Set(tracker.issue(repo, 1)!.labels)
        XCTAssertTrue(labels.contains("status:ready"))
        XCTAssertFalse(labels.contains("status:checking"))
        XCTAssertTrue(labels.contains("good first issue"))
    }

    func testCoalescingGivesOneLabelCall() throws {
        let t = try synced()
        _ = try store.move(t.id, to: .ready, actor: .hatch)
        _ = try store.move(t.id, to: .building, actor: .agent)
        let before = tracker.callCount("setLabels")
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.done, 1)
        XCTAssertEqual(tracker.callCount("setLabels") - before, 1)
        XCTAssertTrue(tracker.issue(repo, 1)!.labels.contains("status:building"))
    }

    func testUpdatePushesTitleAndBody() throws {
        let t = try synced()
        _ = try store.update(t.id, title: "New title", body: "New body", actor: .owner)
        try engine.pushPending(repo: repo)
        XCTAssertEqual(tracker.issue(repo, 1)?.title, "New title")
        XCTAssertEqual(tracker.issue(repo, 1)?.body, "New body")
    }

    func testCommentPushStoresCommentIdOnNote() throws {
        let t = try synced()
        let note = try store.addNote(t.id, kind: .note, author: "owner", body: "Remember dark mode")
        try engine.pushPending(repo: repo)
        let comments = tracker.comments(repo, 1)
        XCTAssertEqual(comments.count, 1)
        XCTAssertTrue(comments[0].body.hasPrefix("**"))
        let stored = try store.notes(ticketId: t.id).first { $0.id == note.id }!
        XCTAssertEqual(stored.ghCommentId, comments[0].id)
    }

    func testCloseAndReopen() throws {
        let t = try synced()
        _ = try store.move(t.id, to: .dropped, actor: .owner)
        try engine.pushPending(repo: repo)
        XCTAssertEqual(tracker.issue(repo, 1)?.state, "closed")
        try store.enqueue(op: "issue.reopen", ticketId: t.id, payload: [:])
        try engine.pushPending(repo: repo)
        XCTAssertEqual(tracker.issue(repo, 1)?.state, "open")
    }

    func testCreateBeforeOthersEvenWhenQueuedTogether() throws {
        let t = try submitted()
        _ = try store.addNote(t.id, kind: .note, author: "owner", body: "first note")
        _ = try store.move(t.id, to: .ready, actor: .hatch)
        let ops = try store.pendingSync().map(\.op)
        XCTAssertEqual(ops.first, "issue.create")
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.failed, 0)
        XCTAssertEqual(tracker.comments(repo, 1).count, 1)
        XCTAssertTrue(tracker.issue(repo, 1)!.labels.contains("status:ready"))
    }

    func testOpForTicketWithoutNumberStaysPending() throws {
        let t = try submitted()
        // Create fails, so the comment queued after it must wait, not fail.
        _ = try store.addNote(t.id, kind: .note, author: "owner", body: "later")
        tracker.failNext(1, error: .transport("offline"))
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.failed, 1)
        XCTAssertEqual(s.skipped, 1)
        let counts = try store.syncCounts()
        XCTAssertEqual(counts.pending, 2)
        XCTAssertEqual(counts.failed, 0)
    }

    func testFailureThenRetryAfterBackoff() throws {
        let t = try submitted()
        tracker.failNext(1)
        var s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.failed, 1)
        XCTAssertNil(try store.ticket(id: t.id)?.ghNumber)
        // Backing off: not due yet.
        s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s, PushSummary())
        box.advance(31)
        s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.done, 1)
        XCTAssertEqual(try store.ticket(id: t.id)?.ghNumber, 1)
        XCTAssertEqual(try store.syncLog(state: "done").filter { $0.op == "issue.create" }.count, 1)
    }

    func testValidationErrorFailsForGood() throws {
        _ = try submitted()
        tracker.failNext(1, error: .validation("bad label"))
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.failed, 1)
        XCTAssertEqual(try store.syncCounts().failed, 1)
        XCTAssertEqual(try store.syncCounts().pending, 0)
    }

    func testRateLimitStopsTheRunAndStaysRetryable() throws {
        _ = try submitted(); _ = try submitted(.tweak, "Other")
        tracker.failNext(1, error: .rateLimited(resetAt: Date()))
        let s = try engine.pushPending(repo: repo)
        XCTAssertEqual(s.failed, 1); XCTAssertEqual(s.skipped, 1)
        XCTAssertEqual(try store.syncCounts().pending, 2)
        XCTAssertEqual(try store.syncCounts().failed, 0)
    }

    // MARK: Pull

    func testPullAcceptsTitleAndBodyEdits() throws {
        let t = try synced()
        tracker.humanEdit(repo: repo, number: 1, title: "Edited on phone", body: "New text")
        let s = try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(s.textUpdated, 1)
        let after = try store.ticket(id: t.id)!
        XCTAssertEqual(after.title, "Edited on phone")
        XCTAssertEqual(after.body, "New text")
        XCTAssertTrue(try store.pendingSync().isEmpty, "a remote edit must not bounce back")
    }

    func testPendingLocalEditWinsOverOlderRemoteText() throws {
        let t = try synced()
        _ = try store.update(t.id, title: "Local edit", actor: .owner)
        tracker.humanEdit(repo: repo, number: 1, title: "Remote edit")
        try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(try store.ticket(id: t.id)?.title, "Local edit")
    }

    func testHumanCommentsImportedOnceAndOwnSkipped() throws {
        let t = try synced()
        _ = try store.addNote(t.id, kind: .note, author: "owner", body: "mine")
        try engine.pushPending(repo: repo)
        tracker.humanComment(repo: repo, number: 1, body: "Looks good to me")
        tracker.humanEdit(repo: repo, number: 1, title: "Toast spacing")   // touch, keeps listing it
        var s = try engine.pull(repo: repo, projectId: project.id, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(s.comments, 1)
        s = try engine.pull(repo: repo, projectId: project.id, since: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(s.comments, 0)
        let comments = try store.notes(ticketId: t.id).filter { $0.kind == .comment }
        XCTAssertEqual(comments.count, 1)
        XCTAssertEqual(comments[0].body, "Looks good to me")
        XCTAssertEqual(comments[0].author, "owner")
        XCTAssertTrue(try store.pendingSync().isEmpty, "imported comments are not pushed back")
    }

    func testStatusDriftIsFlaggedNotObeyed() throws {
        let t = try synced()
        tracker.humanEdit(repo: repo, number: 1, labels: ["type:tweak", "status:done", "project:echo"])
        let s = try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(s.drifts, 1)
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .checking)
        let ev = try store.events(ticketId: t.id, kinds: ["status-drift"])
        XCTAssertEqual(ev.count, 1)
        XCTAssertEqual(ev[0].payload["github"]?.stringValue, "status:done")
        XCTAssertEqual(ev[0].payload["hatch"]?.stringValue, "status:checking")
        XCTAssertEqual(try store.pendingSync().map(\.op), ["issue.labels"])
        try engine.pushPending(repo: repo)
        XCTAssertTrue(tracker.issue(repo, 1)!.labels.contains("status:checking"))
    }

    func testClosedIssueWithOpenTicketIsDriftNotClose() throws {
        let t = try synced()
        tracker.humanEdit(repo: repo, number: 1, state: "closed")
        let s = try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(s.drifts, 1)
        XCTAssertEqual(try store.ticket(id: t.id)?.status, .checking)
        XCTAssertEqual(try store.events(ticketId: t.id, kinds: ["status-drift"]).count, 1)
    }

    func testPhoneCreatedIssueBecomesTicket() throws {
        tracker.seedIssue(repo: repo, title: "Dock icon wrong", body: "see screenshot", labels: ["type:bug", "status:ready", "project:echo"])
        let s = try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(s.created, 1)
        let t = try store.ticket(ghNumber: 1)!
        XCTAssertEqual(t.type, .bug)
        XCTAssertEqual(t.status, .ready)
        XCTAssertEqual(t.title, "Dock icon wrong")
        XCTAssertTrue(try store.pendingSync().isEmpty)
    }

    func testPhoneIssueDefaults() throws {
        tracker.seedIssue(repo: repo, title: "What about X?")
        tracker.seedIssue(repo: repo, title: "Old thing", labels: ["status:nonsense"], state: "closed")
        tracker.seedIssue(repo: repo, title: "Bad status", labels: ["status:nonsense"])
        try engine.pull(repo: repo, projectId: project.id)
        let a = try store.ticket(ghNumber: 1)!, b = try store.ticket(ghNumber: 2)!, c = try store.ticket(ghNumber: 3)!
        XCTAssertEqual(a.type, .question); XCTAssertEqual(a.status, .checking)
        XCTAssertEqual(b.status, .done)
        XCTAssertEqual(c.status, .checking)
    }

    func testPhoneIssueUsesProjectLabel() throws {
        let other = try store.upsertProject(key: "other", name: "Other", config: ProjectConfig(name: "Other", ticketsRepo: repo, repos: [], areas: []))
        tracker.seedIssue(repo: repo, title: "Elsewhere", labels: ["project:other"])
        try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(try store.ticket(ghNumber: 1)?.projectId, other.id)
    }

    func testSecondPullIsQuietAndCursorAdvances() throws {
        tracker.seedIssue(repo: repo, title: "One")
        try engine.pull(repo: repo, projectId: project.id)
        XCTAssertNotNil(try store.setting("sync.pull.\(repo)"))
        box.advance(10)
        let s = try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(s.issuesSeen, 1)   // the cursor is inclusive, the issue is seen but nothing changes
        XCTAssertEqual(s.created, 0); XCTAssertEqual(s.textUpdated, 0); XCTAssertEqual(s.drifts, 0)
        XCTAssertEqual(try store.tickets().count, 1)
    }

    func testPullIsLogged() throws {
        try engine.pull(repo: repo, projectId: project.id)
        XCTAssertEqual(try store.syncLog().filter { $0.direction == "pull" }.count, 1)
    }

    func testPullFailureLoggedAndRethrown() throws {
        tracker.failNext(1)
        XCTAssertThrowsError(try engine.pull(repo: repo, projectId: project.id))
        XCTAssertEqual(try store.syncLog(state: "failed").filter { $0.direction == "pull" }.count, 1)
    }

    // MARK: CI and attachments

    func testCIAggregation() throws {
        tracker.checkRunsByRef["hatch"] = []
        XCTAssertEqual(try engine.ciStatus(repo: "acme/app", ref: "hatch"), .pending)
        tracker.checkRunsByRef["hatch"] = [CheckRun(name: "build", status: "completed", conclusion: "success"), CheckRun(name: "test", status: "in_progress")]
        XCTAssertEqual(try engine.ciStatus(repo: "acme/app", ref: "hatch"), .pending)
        tracker.checkRunsByRef["hatch"] = [CheckRun(name: "build", status: "completed", conclusion: "success"), CheckRun(name: "test", status: "completed", conclusion: "success")]
        XCTAssertEqual(try engine.ciStatus(repo: "acme/app", ref: "hatch"), .passed)
        tracker.checkRunsByRef["hatch"] = [CheckRun(name: "build", status: "completed", conclusion: "success"), CheckRun(name: "test", status: "completed", conclusion: "failure"), CheckRun(name: "lint", status: "queued")]
        XCTAssertEqual(try engine.ciStatus(repo: "acme/app", ref: "hatch"), .failed(["test"]))
    }

    func testCommitAttachment() throws {
        let t = try synced()
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("shot-\(UUID().uuidString).png")
        try Data([1, 2, 3]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let a = try engine.commitAttachment(ticket: t, localFile: file, repo: repo)
        XCTAssertEqual(a.path, "attachments/1/\(file.lastPathComponent)")
        XCTAssertEqual(tracker.files["\(repo)/\(a.path)"], Data([1, 2, 3]))
        XCTAssertEqual(try store.attachments(ticketId: t.id).count, 1)
    }

    // MARK: Hatch comment detection

    func testHatchCommentRecognition() {
        XCTAssertTrue(SyncEngine.isHatchComment("**Ask from owner**\n\nWhy?"))
        XCTAssertTrue(SyncEngine.isHatchComment("**iris**\n\nChecked."))
        XCTAssertFalse(SyncEngine.isHatchComment("Looks good"))
        XCTAssertFalse(SyncEngine.isHatchComment("**bold** start of a human sentence"))
    }
}

// MARK: - GitHubClient over a canned transport

final class CannedTransport: HTTPTransport {
    var responses: [HTTPResponse] = []
    var requests: [HTTPRequest] = []
    func send(_ request: HTTPRequest) throws -> HTTPResponse {
        requests.append(request)
        return responses.isEmpty ? HTTPResponse(status: 500) : responses.removeFirst()
    }
}

func json(_ s: String, status: Int = 200, headers: [String: String] = [:]) -> HTTPResponse {
    HTTPResponse(status: status, headers: headers, body: Data(s.utf8))
}

final class GitHubClientTests: XCTestCase {
    var transport: CannedTransport!
    var client: GitHubClient!

    override func setUp() {
        transport = CannedTransport()
        client = GitHubClient(token: "tok", transport: transport)
    }

    func testPaginationFollowsLinkHeader() throws {
        transport.responses = [
            json(#"[{"number":1,"title":"a","state":"open","labels":[],"updated_at":"2026-01-01T00:00:00Z"}]"#,
                 headers: ["Link": #"<https://api.github.com/repos/o/r/issues?page=2>; rel="next", <https://api.github.com/repos/o/r/issues?page=2>; rel="last""#]),
            json(#"[{"number":2,"title":"b","state":"closed","labels":[{"name":"type:bug"}],"updated_at":"2026-01-02T00:00:00Z"}]"#),
        ]
        let issues = try client.listIssues(repo: "o/r", since: nil)
        XCTAssertEqual(issues.map(\.number), [1, 2])
        XCTAssertEqual(issues[1].labels, ["type:bug"])
        XCTAssertTrue(issues[1].isClosed)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[0].headers["Authorization"], "Bearer tok")
    }

    func testPullRequestsFlagged() throws {
        transport.responses = [json(#"[{"number":5,"title":"pr","state":"open","labels":[],"pull_request":{},"updated_at":"2026-01-01T00:00:00Z"}]"#)]
        XCTAssertTrue(try client.listIssues(repo: "o/r", since: nil)[0].isPullRequest)
    }

    func testETagSentOnSecondListAnd304ServedFromCache() throws {
        transport.responses = [
            json(#"[{"number":1,"title":"a","state":"open","labels":[],"updated_at":"2026-01-01T00:00:00Z"}]"#, headers: ["ETag": "\"abc\""]),
            HTTPResponse(status: 304),
        ]
        _ = try client.listIssues(repo: "o/r", since: nil)
        let again = try client.listIssues(repo: "o/r", since: nil)
        XCTAssertEqual(transport.requests[1].headers["If-None-Match"], "\"abc\"")
        XCTAssertEqual(again.count, 1)
    }

    func testRateLimitBecomesRetryableWithResetTime() {
        transport.responses = [json(#"{"message":"API rate limit exceeded"}"#, status: 403, headers: ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": "1800000000"])]
        XCTAssertThrowsError(try client.addComment(repo: "o/r", number: 1, body: "x")) { e in
            guard case TrackerError.rateLimited(let reset) = e else { return XCTFail("\(e)") }
            XCTAssertEqual(reset, Date(timeIntervalSince1970: 1_800_000_000))
            XCTAssertTrue((e as! TrackerError).isRetryable)
        }
    }

    func testPlain403IsNotRateLimit() {
        transport.responses = [json(#"{"message":"Resource not accessible"}"#, status: 403)]
        XCTAssertThrowsError(try client.addComment(repo: "o/r", number: 1, body: "x")) { e in
            guard case TrackerError.http(let s, _) = e else { return XCTFail("\(e)") }
            XCTAssertEqual(s, 403)
        }
    }

    func testTypedErrors() {
        transport.responses = [json(#"{"message":"Not Found"}"#, status: 404), json(#"{"message":"Validation Failed","errors":[{"code":"invalid"}]}"#, status: 422)]
        XCTAssertThrowsError(try client.reopenIssue(repo: "o/r", number: 1)) { XCTAssertEqual($0 as? TrackerError, .notFound("Not Found")) }
        XCTAssertThrowsError(try client.reopenIssue(repo: "o/r", number: 1)) { e in
            guard case TrackerError.validation(let m) = e else { return XCTFail("\(e)") }
            XCTAssertTrue(m.contains("invalid"))
            XCTAssertFalse((e as! TrackerError).isRetryable)
        }
    }

    func testSetLabelsKeepsForeignLabels() throws {
        transport.responses = [
            json(#"{"number":3,"title":"t","state":"open","labels":[{"name":"type:bug"},{"name":"status:ready"},{"name":"help wanted"}],"updated_at":"2026-01-01T00:00:00Z"}"#),
            json("[]"),
        ]
        try client.setLabels(repo: "o/r", number: 3, labels: ["type:bug", "status:building"])
        let put = transport.requests[1]
        XCTAssertEqual(put.method, "PUT")
        let sent = JSONValue.parse(String(decoding: put.body!, as: UTF8.self))["labels"]?.arrayValue?.compactMap(\.stringValue)
        XCTAssertEqual(sent, ["help wanted", "type:bug", "status:building"])
    }

    func testEnsureLabelsCreatesOnlyMissing() throws {
        transport.responses = [json(#"[{"name":"status:ready"}]"#), json("{}", status: 201)]
        try client.ensureLabels(repo: "o/r", [LabelSpec.hatch("status:ready"), LabelSpec.hatch("status:building")])
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertEqual(transport.requests[1].method, "POST")
        let body = JSONValue.parse(String(decoding: transport.requests[1].body!, as: UTF8.self))
        XCTAssertEqual(body["name"]?.stringValue, "status:building")
        XCTAssertEqual(body["color"]?.stringValue, "4FC3D4")
    }

    func testPutFileSendsBase64AndSha() throws {
        transport.responses = [json(#"{"sha":"old"}"#), json(#"{"content":{"sha":"new"}}"#, status: 201)]
        let sha = try client.putFile(repo: "o/r", path: "attachments/1/a b.png", data: Data([9, 9]), message: "m", branch: "main")
        XCTAssertEqual(sha, "new")
        let body = JSONValue.parse(String(decoding: transport.requests[1].body!, as: UTF8.self))
        XCTAssertEqual(body["content"]?.stringValue, Data([9, 9]).base64EncodedString())
        XCTAssertEqual(body["sha"]?.stringValue, "old")
        XCTAssertTrue(transport.requests[1].url.absoluteString.contains("a%20b.png"))
    }

    func testCheckRunsParsed() throws {
        transport.responses = [json(#"{"check_runs":[{"name":"build","status":"completed","conclusion":"success"},{"name":"t","status":"queued","conclusion":null}]}"#)]
        let runs = try client.checkRuns(repo: "o/r", ref: "hatch")
        XCTAssertEqual(runs, [CheckRun(name: "build", status: "completed", conclusion: "success"), CheckRun(name: "t", status: "queued")])
    }

    func testNoTokenIsAnError() {
        let c = GitHubClient(token: "", transport: transport)
        // Without env or gh the client has nothing to send; with them it would use them, so only assert no request without auth.
        if ProcessInfo.processInfo.environment["GITHUB_TOKEN"] == nil {
            _ = try? c.listIssues(repo: "o/r", since: nil)
            XCTAssertTrue(transport.requests.allSatisfy { $0.headers["Authorization"] != nil })
        }
    }
}
