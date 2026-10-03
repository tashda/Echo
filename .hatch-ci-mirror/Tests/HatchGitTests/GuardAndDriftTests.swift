import XCTest
import HatchCore
@testable import HatchGit

final class GuardAndDriftTests: GitTestCase {
    func testPolicyDescribesAllowedPattern() throws {
        let p = GuardPolicy(ticket: try makeTicket("x", gh: 151))
        XCTAssertEqual(p.allowedBranchPattern, "ticket/151-*")
        XCTAssertTrue(p.allows(remoteRef: "refs/heads/ticket/151-toast"))
        XCTAssertFalse(p.allows(remoteRef: "refs/heads/ticket/1510-other"))
        XCTAssertFalse(p.allows(remoteRef: "refs/heads/dev"))
        XCTAssertFalse(p.allows(remoteRef: "refs/tags/v1"))
    }

    func testHookInstalledPerWorktreeOnly() throws {
        let ws = try manager.create(ticket: try makeTicket("Guarded", gh: 20), repo: app)
        XCTAssertTrue(manager.guardsInstalled(ws))
        let shared = try git.run(["config", "--local", "--get", "core.hooksPath"], in: app.localPath!)
        XCTAssertFalse(shared.stdout.contains("hatch-hooks"), "the owner checkout keeps its own hooks")
    }

    func testPushToDefaultBranchRefusedAndTicketBranchAllowed() throws {
        let bare = try addBareRemote(to: app)
        let (_, ws) = try ticketWithEdit("Guarded", gh: 21, file: "a.txt", text: "x\n")
        let bad = try git.run(["push", "origin", "HEAD:refs/heads/dev"], in: ws.path)
        XCTAssertFalse(bad.ok)
        XCTAssertTrue(bad.stderr.contains("refused"), bad.stderr)
        let bad2 = try git.run(["push", "origin", "HEAD:refs/heads/ticket/22-other"], in: ws.path)
        XCTAssertFalse(bad2.ok, "another ticket's branch is refused too")
        let ok = try git.run(["push", "origin", "HEAD:refs/heads/\(ws.branch)"], in: ws.path)
        XCTAssertTrue(ok.ok, ok.stderr)
        XCTAssertEqual(try g(["rev-parse", ws.branch], bare), try g(["rev-parse", "HEAD"], ws.path))
        XCTAssertNotEqual(try g(["rev-parse", "dev"], bare), try g(["rev-parse", "HEAD"], ws.path))
    }

    func testOwnerCheckoutCanStillPushDefaultBranch() throws {
        _ = try addBareRemote(to: app)
        _ = try manager.create(ticket: try makeTicket("Guarded", gh: 23), repo: app)
        try write(app.localPath!, "owner.txt", "o")
        try g(["add", "-A"], app.localPath!); try g(["commit", "-q", "-m", "owner"], app.localPath!)
        XCTAssertTrue(try git.run(["push", "origin", "dev"], in: app.localPath!).ok)
    }

    func testClaimDriftWarnsOnUnclaimedFiles() throws {
        let t = try makeTicket("Drift", gh: 30)
        try store.claim(ticketId: t.id, repoId: app.id, paths: ["src/ui/**", "a.txt"])
        let ws = try manager.create(ticket: t, repo: app)
        try write(ws.path, "src/ui/button.swift", "x")
        try write(ws.path, "a.txt", "changed\n")
        try manager.commit(ws, message: "ui")
        try write(ws.path, "src/net/client.swift", "y")      // uncommitted, untracked, unclaimed
        try write(ws.path, "b.txt", "dirty\n")               // uncommitted, tracked, unclaimed
        let d = try ClaimsFromDiff(store: store, git: git).claimDrift(t, workspace: ws)
        XCTAssertTrue(d.hasDrift)
        XCTAssertEqual(d.unclaimedChanges, ["b.txt", "src/net/client.swift"])
        XCTAssertEqual(d.changedFiles.count, 4)
        XCTAssertEqual(d.untouchedClaims, [])
    }

    func testNoDriftWhenWithinClaims() throws {
        let t = try makeTicket("Tidy", gh: 31)
        try store.claim(ticketId: t.id, repoId: app.id, paths: ["a.txt", "docs/**"])
        let ws = try manager.create(ticket: t, repo: app)
        try write(ws.path, "a.txt", "ok\n")
        let d = try ClaimsFromDiff(store: store, git: git).claimDrift(t, workspace: ws)
        XCTAssertFalse(d.hasDrift)
        XCTAssertEqual(d.untouchedClaims, ["docs/**"])
    }
}
