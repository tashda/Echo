import XCTest
import HatchCore
@testable import HatchGit

final class WorkspaceTests: GitTestCase {
    func testSlugRules() {
        XCTAssertEqual(WorkspaceManager.slug("Toast Spacing in Dark Mode!"), "toast-spacing-in-dark-mode")
        XCTAssertEqual(WorkspaceManager.slug("  --Fix: a/b_c  "), "fix-a-b-c")
        XCTAssertEqual(WorkspaceManager.slug("???"), "ticket")
    }

    func testSlugIsCappedAt40WithoutTrailingHyphen() {
        let s = WorkspaceManager.slug("this is a really long ticket title that keeps going and going")
        XCTAssertLessThanOrEqual(s.count, 40)
        XCTAssertFalse(s.hasSuffix("-"))
        XCTAssertEqual(WorkspaceManager.slug(String(repeating: "abcd ", count: 20)).last, "d")
    }

    func testBranchNamesUseGitHubNumberOrNewId() throws {
        let synced = try makeTicket("Toast spacing", gh: 151)
        XCTAssertEqual(WorkspaceManager.branchName(for: synced), "ticket/151-toast-spacing")
        let local = try makeTicket("Toast spacing")
        XCTAssertEqual(WorkspaceManager.branchName(for: local), "ticket/new-\(local.id)-toast-spacing")
    }

    func testCreateMakesWorktreeOnTicketBranchFromDefaultTip() throws {
        let t = try makeTicket("Toast spacing", gh: 151)
        let ws = try manager.create(ticket: t, repo: app)
        XCTAssertEqual(ws.branch, "ticket/151-toast-spacing")
        XCTAssertEqual(ws.path, tmp + "/projects/.hatch-workspaces/echo-151")
        XCTAssertTrue(FileManager.default.fileExists(atPath: ws.path + "/README.md"))
        XCTAssertEqual(try g(["rev-parse", "--abbrev-ref", "HEAD"], ws.path), "ticket/151-toast-spacing")
        XCTAssertEqual(ws.baseSha, try g(["rev-parse", "dev"], app.localPath!))
        XCTAssertEqual(try store.workspace(ticketId: t.id, repoId: app.id)?.path, ws.path)
    }

    func testCreateIsIdempotent() throws {
        let t = try makeTicket("Toast spacing", gh: 151)
        let a = try manager.create(ticket: t, repo: app)
        try write(a.path, "wip.txt", "x")
        let b = try manager.create(ticket: t, repo: app)
        XCTAssertEqual(a, b)
        XCTAssertEqual(read(b.path, "wip.txt"), "x", "second create must not reset the work")
        XCTAssertEqual(try manager.list().count, 1)
    }

    func testCustomRoot() throws {
        manager.root = tmp + "/elsewhere"
        let ws = try manager.create(ticket: try makeTicket("x", gh: 5), repo: app)
        XCTAssertEqual(ws.path, tmp + "/elsewhere/echo-5")
    }

    func testMainCheckoutIsNeverTouched() throws {
        let main = app.localPath!
        let before = try g(["status", "--porcelain"], main)
        let (_, _) = try ticketWithEdit("Edit a", gh: 1, file: "a.txt", text: "changed\n")
        XCTAssertEqual(try g(["status", "--porcelain"], main), before)
        XCTAssertEqual(read(main, "a.txt"), "line1\nline2\nline3\n")
        XCTAssertEqual(try g(["rev-parse", "--abbrev-ref", "HEAD"], main), "dev")
    }

    func testTwoWorkspacesAreIsolated() throws {
        let (_, w1) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "from one\n")
        let t2 = try makeTicket("Two", gh: 2)
        let w2 = try manager.create(ticket: t2, repo: app)
        XCTAssertEqual(read(w2.path, "a.txt"), "line1\nline2\nline3\n")
        try write(w2.path, "a.txt", "from two\n")
        XCTAssertEqual(read(w1.path, "a.txt"), "from one\n")
        XCTAssertEqual(read(w2.path, "a.txt"), "from two\n")
    }

    func testRemoveKeepsOrDeletesBranch() throws {
        let t = try makeTicket("Keep", gh: 7)
        let ws = try manager.create(ticket: t, repo: app)
        try manager.remove(ws)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ws.path))
        XCTAssertTrue(git.branchExists(ws.branch, in: app.localPath!))
        XCTAssertTrue(try manager.list().isEmpty)

        let again = try manager.create(ticket: t, repo: app)   // recreated on the surviving branch
        XCTAssertTrue(FileManager.default.fileExists(atPath: again.path))
        try manager.remove(again, deleteBranch: true)
        XCTAssertFalse(git.branchExists(ws.branch, in: app.localPath!))
    }

    func testRemoveRefusesDirtyUnlessForced() throws {
        let ws = try manager.create(ticket: try makeTicket("Dirty", gh: 8), repo: app)
        try write(ws.path, "new.txt", "x")
        try g(["add", "new.txt"], ws.path)
        XCTAssertThrowsError(try manager.remove(ws))
        try manager.remove(ws, force: true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: ws.path))
    }

    func testStatusAndCommit() throws {
        let ws = try manager.create(ticket: try makeTicket("Status", gh: 9), repo: app)
        XCTAssertTrue(try manager.status(ws).isClean)
        try write(ws.path, "a.txt", "changed\n")
        try write(ws.path, "dir/new.txt", "n")
        var st = try manager.status(ws)
        XCTAssertEqual(st.dirtyFiles, ["a.txt", "dir/new.txt"])
        XCTAssertEqual(st.commitsAhead, 0)
        let sha = try manager.commit(ws, message: "work")
        XCTAssertNotNil(sha)
        st = try manager.status(ws)
        XCTAssertTrue(st.isClean)
        XCTAssertEqual(st.commitsAhead, 1)
        XCTAssertNil(try manager.commit(ws, message: "nothing"))
    }

    func testMergeBaseIntoBranch() throws {
        let (_, ws) = try ticketWithEdit("Feature", gh: 10, file: "b.txt", text: "mine\n")
        XCTAssertEqual(try manager.mergeBaseIntoBranch(ws), .upToDate)
        try write(app.localPath!, "c.txt", "new on dev\n")
        try g(["add", "-A"], app.localPath!); try g(["commit", "-q", "-m", "dev moves"], app.localPath!)
        guard case .merged = try manager.mergeBaseIntoBranch(ws) else { return XCTFail("expected merge") }
        XCTAssertEqual(read(ws.path, "c.txt"), "new on dev\n")
        XCTAssertEqual(try store.workspace(ticketId: ws.ticketId, repoId: ws.repoId)?.baseSha, try g(["rev-parse", "dev"], app.localPath!))
    }

    func testMergeBaseReportsConflictsAndLeavesTreeClean() throws {
        let (_, ws) = try ticketWithEdit("Feature", gh: 11, file: "a.txt", text: "mine\n")
        try write(app.localPath!, "a.txt", "theirs\n")
        try g(["commit", "-q", "-am", "dev edits a"], app.localPath!)
        XCTAssertEqual(try manager.mergeBaseIntoBranch(ws), .conflicts(["a.txt"]))
        XCTAssertTrue(try manager.status(ws).isClean)
        XCTAssertEqual(read(ws.path, "a.txt"), "mine\n")
    }

    func testCreateWorksOfflineWithUnreachableRemote() throws {
        try g(["remote", "add", "origin", tmp + "/does/not/exist.git"], app.localPath!)
        let ws = try manager.create(ticket: try makeTicket("Offline", gh: 12), repo: app)
        XCTAssertTrue(FileManager.default.fileExists(atPath: ws.path + "/README.md"))
    }

    func testCreateFetchesNewerRemoteTip() throws {
        let bare = try addBareRemote(to: app)
        let other = tmp + "/other"
        try g(["clone", "-q", bare, other], tmp)
        try write(other, "remote.txt", "from remote\n")
        try g(["add", "-A"], other); try g(["commit", "-q", "-m", "remote work"], other); try g(["push", "-q", "origin", "dev"], other)
        let ws = try manager.create(ticket: try makeTicket("Fresh", gh: 13), repo: app)
        XCTAssertEqual(read(ws.path, "remote.txt"), "from remote\n")
    }
}
