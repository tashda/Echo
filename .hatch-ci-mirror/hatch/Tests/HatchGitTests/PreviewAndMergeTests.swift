import XCTest
import HatchCore
@testable import HatchGit

final class PreviewAndMergeTests: GitTestCase {
    var builder: PreviewBuilder!
    override func setUpWithError() throws {
        try super.setUpWithError()
        builder = PreviewBuilder(workspaces: manager)
    }

    func testCleanPreviewOfThreeBranches() throws {
        let (t1, _) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "one\n")
        let (t2, _) = try ticketWithEdit("Two", gh: 2, file: "b.txt", text: "two\n")
        let (t3, _) = try ticketWithEdit("Three", gh: 3, file: "c.txt", text: "three\n")
        let r = try builder.build(repo: app, tickets: [t1, t2, t3])
        XCTAssertTrue(r.isClean)
        XCTAssertEqual(r.mergedTicketIds, [t1.id, t2.id, t3.id])
        XCTAssertEqual(r.preview.name, "Preview 01")
        XCTAssertEqual(r.preview.branch, "preview/01")
        XCTAssertEqual(r.preview.state, "merged")
        let path = try XCTUnwrap(r.worktreePath)
        XCTAssertEqual(read(path, "a.txt"), "one\n"); XCTAssertEqual(read(path, "b.txt"), "two\n"); XCTAssertEqual(read(path, "c.txt"), "three\n")
        XCTAssertEqual(try g(["rev-list", "--merges", "--count", "HEAD"], path), "3", "--no-ff gives a merge commit per ticket")
        XCTAssertEqual(try store.previewTickets(previewId: r.preview.id).map(\.ticketId), [t1.id, t2.id, t3.id])
        XCTAssertEqual(read(app.localPath!, "a.txt"), "line1\nline2\nline3\n")
    }

    func testConflictNamesTheRightPair() throws {
        let (t1, _) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "one\n")
        let (t2, _) = try ticketWithEdit("Two", gh: 2, file: "b.txt", text: "two\n")
        let (t3, _) = try ticketWithEdit("Three", gh: 3, file: "a.txt", text: "three\n")
        let r = try builder.build(repo: app, tickets: [t1, t2, t3])
        let c = try XCTUnwrap(r.conflict)
        XCTAssertEqual(c.ticketId, t3.id)
        XCTAssertEqual(c.againstTicketId, t1.id, "ticket 3 collides with 1, not with the nearer 2")
        XCTAssertEqual(c.files, ["a.txt"])
        XCTAssertEqual(c.choices, [.drop, .stack, .askAgentToResolve])
        XCTAssertEqual(r.mergedTicketIds, [t1.id, t2.id])
        XCTAssertEqual(r.preview.state, "conflict")
    }

    func testConflictLeavesNoHalfMergedWorktreeOrBranch() throws {
        let (t1, _) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "one\n")
        let (t2, _) = try ticketWithEdit("Two", gh: 2, file: "a.txt", text: "two\n")
        let r = try builder.build(repo: app, tickets: [t1, t2])
        XCTAssertNil(r.worktreePath)
        XCTAssertFalse(git.branchExists("preview/01", in: app.localPath!))
        let trees = try g(["worktree", "list", "--porcelain"], app.localPath!)
        XCTAssertFalse(trees.contains("preview"), trees)
        XCTAssertFalse(trees.contains("scratch"), trees)
        XCTAssertEqual(try g(["status", "--porcelain"], app.localPath!), "")
    }

    func testDropThenRebuildSucceedsWithNextNumber() throws {
        let (t1, _) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "one\n")
        let (t2, _) = try ticketWithEdit("Two", gh: 2, file: "a.txt", text: "two\n")
        XCTAssertNotNil(try builder.build(repo: app, tickets: [t1, t2]).conflict)
        let r = try builder.build(repo: app, tickets: [t1])
        XCTAssertTrue(r.isClean)
        XCTAssertEqual(r.preview.name, "Preview 02")
    }

    func testDiscardRemovesWorktreeAndBranch() throws {
        let (t1, _) = try ticketWithEdit("One", gh: 1, file: "a.txt", text: "one\n")
        let r = try builder.build(repo: app, tickets: [t1])
        let path = try XCTUnwrap(r.worktreePath)
        try builder.discard(r.preview, repo: app)
        XCTAssertFalse(FileManager.default.fileExists(atPath: path))
        XCTAssertFalse(git.branchExists("preview/01", in: app.localPath!))
        XCTAssertEqual(try store.preview(id: r.preview.id)?.state, "discarded")
        XCTAssertTrue(git.branchExists("ticket/1-one", in: app.localPath!), "ticket branches survive")
    }

    func testPreviewNeedsWorkspace() throws {
        let t = try makeTicket("No ws", gh: 9)
        XCTAssertThrowsError(try builder.build(repo: app, tickets: [t]))
    }

    func testPreviewDisplayNames() {
        XCTAssertEqual(PreviewBuilder.displayName(3), "Preview 03")
        XCTAssertEqual(PreviewBuilder.branchName(12), "preview/12")
    }

    // MARK: Merge plan

    func testSemverBump() {
        XCTAssertEqual(Semver.nextPatch(after: ["v1.2.3", "v1.10.0", "v1.9.9", "junk"]), "v1.10.1")
        XCTAssertEqual(Semver.nextPatch(after: []), "v0.1.0")
    }

    func testMergePlanOrderAndTagBump() throws {
        let ds = try repo(.designSystem), sp = try repo(.specimens)
        try g(["tag", "v1.4.2"], ds.localPath!)
        let (t1, _) = try ticketWithEdit("Button", gh: 1, file: "a.txt", text: "ds\n", repo: ds)
        let (t1app, _) = (t1, ())
        _ = try manager.create(ticket: t1app, repo: app)
        let (t2, _) = try ticketWithEdit("Round", gh: 2, file: "b.txt", text: "sp\n", repo: sp)
        _ = t2
        let plan = try MergePlan.build(project: project, tickets: [t1, t2], store: store, git: git)
        XCTAssertEqual(plan.integrationBranch, "hatch")
        XCTAssertEqual(plan.steps.map(\.kind), [.mergeTickets, .tag, .mergeTickets, .mergeTickets])
        XCTAssertEqual(plan.steps.map(\.repoRole), [.designSystem, .designSystem, .specimens, .app])
        XCTAssertEqual(plan.steps[1].tag, "v1.4.3")
        XCTAssertEqual(plan.steps[1].commands, [["tag", "-a", "v1.4.3", "-m", "Hatch v1.4.3"]])
        XCTAssertTrue(plan.steps[3].description.contains("v1.4.3"))
        XCTAssertEqual(plan.steps.map(\.index), [0, 1, 2, 3])
        XCTAssertTrue(plan.steps[0].commands.contains { $0.last == "ticket/1-button" })
    }

    func testPlanSkipsReposWithoutTickets() throws {
        let (t, _) = try ticketWithEdit("Only app", gh: 5, file: "a.txt", text: "x\n")
        let plan = try MergePlan.build(project: project, tickets: [t], store: store, git: git)
        XCTAssertEqual(plan.steps.map(\.repoRole), [.app])
    }

    func testExecutorDryRunChangesNothing() throws {
        let (t, _) = try ticketWithEdit("Only app", gh: 5, file: "a.txt", text: "x\n")
        let plan = try MergePlan.build(project: project, tickets: [t], store: store, git: git)
        let run = try MergeExecutor(workspaces: manager).run(plan, dryRun: true)
        XCTAssertTrue(run.succeeded)
        XCTAssertTrue(run.results.allSatisfy(\.skipped))
        XCTAssertFalse(git.branchExists("hatch", in: app.localPath!))
    }

    func testExecutorMergesTagsAndLeavesOwnerCheckoutAlone() throws {
        let ds = try repo(.designSystem)
        let (t1, _) = try ticketWithEdit("Button", gh: 1, file: "a.txt", text: "ds\n", repo: ds)
        _ = try manager.create(ticket: t1, repo: app)
        let plan = try MergePlan.build(project: project, tickets: [t1], store: store, git: git)
        let run = try MergeExecutor(workspaces: manager).run(plan)
        XCTAssertTrue(run.succeeded, run.results.map(\.output).joined())
        XCTAssertEqual(run.results.count, 3)
        XCTAssertEqual(try g(["tag", "--list", "v*"], ds.localPath!), "v0.1.0")
        XCTAssertEqual(try g(["show", "hatch:a.txt"], ds.localPath!), "ds")
        XCTAssertTrue(git.succeeds(["merge-base", "--is-ancestor", "ticket/1-button", "hatch"], in: app.localPath!))
        XCTAssertEqual(read(ds.localPath!, "a.txt"), "line1\nline2\nline3\n")
        XCTAssertTrue(try store.events(ticketId: t1.id).contains { $0.kind == "merge-step" })
    }

    func testExecutorStopsAtFirstFailure() throws {
        let ds = try repo(.designSystem)
        let (t1, _) = try ticketWithEdit("A", gh: 1, file: "a.txt", text: "one\n", repo: ds)
        let (t2, _) = try ticketWithEdit("B", gh: 2, file: "a.txt", text: "two\n", repo: ds)
        _ = try manager.create(ticket: t1, repo: app)
        let plan = try MergePlan.build(project: project, tickets: [t1, t2], store: store, git: git)
        let run = try MergeExecutor(workspaces: manager).run(plan)
        XCTAssertFalse(run.succeeded)
        XCTAssertEqual(run.results.count, 1, "no tag, no app step after the failed merge")
        XCTAssertEqual(run.failedStep?.kind, .mergeTickets)
        XCTAssertEqual(try g(["tag", "--list", "v*"], ds.localPath!), "")
        let wt = URL(fileURLWithPath: ds.localPath!).deletingLastPathComponent().appendingPathComponent(".hatch-workspaces/echo-ds-integration-hatch").path
        XCTAssertEqual(try g(["status", "--porcelain"], wt), "", "aborted merge leaves a clean worktree")
    }

    func testPromoteRefusedWithoutCI() throws {
        let (t, _) = try ticketWithEdit("Only app", gh: 5, file: "a.txt", text: "x\n")
        let ex = MergeExecutor(workspaces: manager)
        _ = try ex.run(try MergePlan.build(project: project, tickets: [t], store: store, git: git))
        let before = try g(["rev-parse", "dev"], app.localPath!)
        XCTAssertThrowsError(try ex.promote(repo: app, integration: "hatch", into: "dev", ciPassed: false)) { XCTAssertTrue($0 is GitError) }
        XCTAssertEqual(try g(["rev-parse", "dev"], app.localPath!), before)
    }

    func testPromoteFastForwardsWhenCIPassed() throws {
        let (t, _) = try ticketWithEdit("Only app", gh: 5, file: "a.txt", text: "x\n")
        let exec = MergeExecutor(workspaces: manager)
        _ = try exec.run(try MergePlan.build(project: project, tickets: [t], store: store, git: git))
        let res = try exec.promote(repo: app, integration: "hatch", into: "dev", ciPassed: true)
        XCTAssertTrue(res.fastForward)
        XCTAssertEqual(try g(["rev-parse", "dev"], app.localPath!), try g(["rev-parse", "hatch"], app.localPath!))
        XCTAssertEqual(read(app.localPath!, "a.txt"), "x\n", "checked-out dev is fast-forwarded in place")
    }

    func testPromoteMakesMergeCommitWhenDefaultMovedOn() throws {
        let (t, _) = try ticketWithEdit("Only app", gh: 5, file: "a.txt", text: "x\n")
        let exec = MergeExecutor(workspaces: manager)
        _ = try exec.run(try MergePlan.build(project: project, tickets: [t], store: store, git: git))
        try write(app.localPath!, "b.txt", "dev moved\n")
        try g(["commit", "-q", "-am", "dev moves"], app.localPath!)
        let res = try exec.promote(repo: app, integration: "hatch", into: "dev", ciPassed: true)
        XCTAssertFalse(res.fastForward)
        XCTAssertEqual(read(app.localPath!, "a.txt"), "x\n")
        XCTAssertEqual(read(app.localPath!, "b.txt"), "dev moved\n")
    }
}
