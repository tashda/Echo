import Foundation
import HatchCore

/// One step of the merge plan, as plain data (decision J5): shown to the owner first, then run by `MergeExecutor`.
public struct MergeStep: Equatable, Sendable {
    public enum Kind: String, Sendable { case mergeTickets, tag }
    public let index: Int
    public let kind: Kind
    public let repoId: Int
    public let repoRole: RepoRole
    /// Branch the commands run on: the integration branch, checked out in a Hatch-owned worktree (never the owner's checkout).
    public let targetBranch: String
    public let description: String
    /// git arguments, run in order inside the target worktree.
    public let commands: [[String]]
    public let ticketIds: [Int]
    /// The version created by a tag step; also carried by the app step as the version it should bump to.
    public let tag: String?
}

public struct MergePlan: Equatable, Sendable {
    public let integrationBranch: String
    public let steps: [MergeStep]
    public var isEmpty: Bool { steps.isEmpty }
}

public enum Semver {
    /// Parses `v1.2.3` / `1.2.3`.
    public static func parse(_ tag: String) -> (Int, Int, Int)? {
        var s = Substring(tag); if s.hasPrefix("v") { s = s.dropFirst() }
        let parts = s.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard parts.count == 3, let a = parts[0], let b = parts[1], let c = parts[2] else { return nil }
        return (a, b, c)
    }

    /// Patch bump of the highest `v*` tag; with no tag yet the first version is `v0.1.0`.
    public static func nextPatch(after tags: [String]) -> String {
        let versions = tags.compactMap(parse)
        guard let top = versions.max(by: { ($0.0, $0.1, $0.2) < ($1.0, $1.1, $1.2) }) else { return "v0.1.0" }
        return "v\(top.0).\(top.1).\(top.2 + 1)"
    }
}

public extension MergePlan {
    /// Orders the work: design system first (merge, then tag the next version), then specimens, then the app repo, all
    /// into the project's integration branch. A repo with no approved ticket produces no step. Tickets keep the order given.
    static func build(project: Project, tickets: [Ticket], store: HatchStore, git: GitRunner = ProcessGit()) throws -> MergePlan {
        let integration = project.config?.integrationBranch ?? "hatch"
        var steps: [MergeStep] = []
        var designTag: String?
        for role in [RepoRole.designSystem, .specimens, .app] {
            guard let repo = try store.repo(projectId: project.id, role: role), let dir = repo.localPath else { continue }
            var ids: [Int] = [], cmds: [[String]] = [["merge", "--no-edit", "-m", "Bring \(repo.defaultBranch) into \(integration)", repo.defaultBranch]], names: [String] = []
            for t in tickets {
                guard let ws = try store.workspace(ticketId: t.id, repoId: repo.id), ws.state == "active" else { continue }
                ids.append(t.id); names.append(t.displayNumber)
                cmds.append(["merge", "--no-ff", "-m", "Merge \(t.displayNumber) \(t.title)", ws.branch])
            }
            if ids.isEmpty { continue }
            var desc = "Merge \(names.joined(separator: ", ")) into \(integration) in \(repo.remote)"
            if role == .app, let designTag { desc += " (bump the design system to \(designTag) first)" }
            steps.append(MergeStep(index: steps.count, kind: .mergeTickets, repoId: repo.id, repoRole: role, targetBranch: integration,
                                   description: desc, commands: cmds, ticketIds: ids, tag: role == .app ? designTag : nil))
            if role == .designSystem {
                let tags = (try? git.lines(["tag", "--list", "v*"], in: dir)) ?? []
                let next = Semver.nextPatch(after: tags)
                designTag = next
                steps.append(MergeStep(index: steps.count, kind: .tag, repoId: repo.id, repoRole: role, targetBranch: integration,
                                       description: "Tag \(repo.remote) \(next)", commands: [["tag", "-a", next, "-m", "Hatch \(next)"]], ticketIds: ids, tag: next))
            }
        }
        return MergePlan(integrationBranch: integration, steps: steps)
    }
}

public struct MergeStepResult: Equatable, Sendable {
    public let step: MergeStep
    public let ok: Bool
    public let skipped: Bool        // dry run
    public let output: String
}

public struct MergeRun: Equatable, Sendable {
    public let results: [MergeStepResult]
    public var succeeded: Bool { results.allSatisfy(\.ok) }
    public var failedStep: MergeStep? { results.first { !$0.ok }?.step }
}

public struct PromoteResult: Equatable, Sendable {
    public let sha: String
    public let fastForward: Bool
}

/// Runs a merge plan (decision J5, I6) and promotes the integration branch once CI is green.
public final class MergeExecutor: @unchecked Sendable {
    public let workspaces: WorkspaceManager
    var store: HatchStore { workspaces.store }
    var git: GitRunner { workspaces.git }

    public init(workspaces: WorkspaceManager) { self.workspaces = workspaces }

    /// Runs the steps in order and stops at the first failure (the failed merge is aborted so its worktree is clean).
    /// `dryRun` runs nothing and reports every step as skipped. Progress is written to each ticket's event log.
    public func run(_ plan: MergePlan, dryRun: Bool = false) throws -> MergeRun {
        var results: [MergeStepResult] = []
        for step in plan.steps {
            if dryRun { results.append(MergeStepResult(step: step, ok: true, skipped: true, output: step.commands.map { "git " + $0.joined(separator: " ") }.joined(separator: "\n"))); continue }
            let result = try execute(step)
            results.append(result)
            for t in step.ticketIds {
                try store.record(t, actor: "hatch", kind: "merge-step", payload: ["step": .int(step.index), "what": .string(step.description), "ok": .bool(result.ok), "output": .string(String(result.output.suffix(2000)))])
            }
            if !result.ok { break }
        }
        return MergeRun(results: results)
    }

    private func execute(_ step: MergeStep) throws -> MergeStepResult {
        guard let repo = try store.repo(id: step.repoId) else { throw StoreError.notFound("repo \(step.repoId)") }
        let dir = try integrationWorktree(repo: repo, branch: step.targetBranch)
        var out = ""
        for cmd in step.commands {
            let r = try git.run(cmd, in: dir)
            out += "$ git \(cmd.joined(separator: " "))\n\(r.stdout)\(r.stderr)"
            if !r.ok {
                git.run_ignoringFailure(["merge", "--abort"], in: dir)
                return MergeStepResult(step: step, ok: false, skipped: false, output: out)
            }
        }
        return MergeStepResult(step: step, ok: true, skipped: false, output: out)
    }

    /// A Hatch-owned worktree with the integration branch checked out (created from the default branch when missing).
    func integrationWorktree(repo: Repo, branch: String) throws -> String {
        let repoDir = try workspaces.repoPath(repo)
        let name = URL(fileURLWithPath: repoDir).lastPathComponent
        let path = URL(fileURLWithPath: try workspaces.workspaceRoot(for: repo)).appendingPathComponent("\(name)-integration-\(branch.replacingOccurrences(of: "/", with: "-"))").path
        if workspaces.registeredWorktrees(repoDir).contains(where: { WorkspaceManager.samePath($0, path) }) { return path }
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        try FileManager.default.createDirectory(atPath: URL(fileURLWithPath: path).deletingLastPathComponent().path, withIntermediateDirectories: true)
        if git.branchExists(branch, in: repoDir) {
            try git.git(["worktree", "add", path, branch], in: repoDir)
        } else {
            try git.git(["worktree", "add", "--no-track", "-b", branch, path, git.tip(of: repo.defaultBranch, repo: repoDir)], in: repoDir)
        }
        return path
    }

    /// Moves `into` (normally the default branch) to include `integration`. Refuses unless CI passed (decision I6).
    /// Fast-forwards when it can, otherwise makes a merge commit. The owner's checkout is only touched when it has `into` checked out.
    @discardableResult
    public func promote(repo: Repo, integration: String, into target: String, ciPassed: Bool) throws -> PromoteResult {
        guard ciPassed else { throw GitError.ciRequired("CI has not passed on \(integration); \(target) was not changed.") }
        let dir = try workspaces.repoPath(repo)
        let tip = try git.resolve(integration, in: dir)
        let old = try git.resolve(target, in: dir)
        if tip == old { return PromoteResult(sha: tip, fastForward: true) }
        let checkedOut = checkedOutPath(of: target, repoDir: dir)
        if git.succeeds(["merge-base", "--is-ancestor", old, tip], in: dir) {
            if let checkedOut { try git.git(["merge", "--ff-only", tip], in: checkedOut) }
            else { try git.git(["update-ref", "refs/heads/\(target)", tip, old], in: dir) }
            return PromoteResult(sha: tip, fastForward: true)
        }
        if let checkedOut {
            do { try git.git(["merge", "--no-ff", "-m", "Promote \(integration) into \(target)", tip], in: checkedOut) }
            catch { git.run_ignoringFailure(["merge", "--abort"], in: checkedOut); throw error }
            return PromoteResult(sha: try git.git(["rev-parse", "HEAD"], in: checkedOut), fastForward: false)
        }
        let scratch = URL(fileURLWithPath: try workspaces.workspaceRoot(for: repo)).appendingPathComponent(".scratch-\(UUID().uuidString.prefix(8))").path
        try git.git(["worktree", "add", "--detach", scratch, old], in: dir)
        defer { git.run_ignoringFailure(["worktree", "remove", "--force", scratch], in: dir) }
        try git.git(["merge", "--no-ff", "-m", "Promote \(integration) into \(target)", tip], in: scratch)
        let sha = try git.git(["rev-parse", "HEAD"], in: scratch)
        try git.git(["update-ref", "refs/heads/\(target)", sha, old], in: dir)
        return PromoteResult(sha: sha, fastForward: false)
    }

    private func checkedOutPath(of branch: String, repoDir: String) -> String? {
        var current: String?
        for line in (try? git.lines(["worktree", "list", "--porcelain"], in: repoDir)) ?? [] {
            if line.hasPrefix("worktree ") { current = String(line.dropFirst(9)) }
            else if line == "branch refs/heads/\(branch)" { return current }
        }
        return nil
    }
}
