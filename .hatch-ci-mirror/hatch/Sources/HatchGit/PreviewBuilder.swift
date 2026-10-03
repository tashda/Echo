import Foundation
import HatchCore

/// What the owner can do about a conflict between two tickets (decision J2).
public enum ConflictChoice: String, Equatable, Sendable {
    case drop                  // leave the later ticket out of this Preview
    case stack                 // make the later ticket build on the earlier one (K3 "Stack on #144")
    case askAgentToResolve     // send the later ticket's agent the conflict to resolve
}

/// The first conflict found: which pair, in which files, and what to do next. All plain data for the UI.
public struct PreviewConflict: Equatable, Sendable {
    public let ticketId: Int            // the later ticket (the one that does not fit)
    public let againstTicketId: Int     // the earlier ticket it collides with
    public let branch: String
    public let againstBranch: String
    public let files: [String]
    public let choices: [ConflictChoice]
}

public struct PreviewResult: Equatable, Sendable {
    public let preview: Preview
    /// The throwaway worktree to build in. nil after a conflict: a half-merged tree is never left behind.
    public let worktreePath: String?
    public let mergedTicketIds: [Int]
    public let conflict: PreviewConflict?
    public var isClean: Bool { conflict == nil }
}

/// Builds the throwaway `preview/<NN>` branch (decisions J1, J2): the owner selects tickets, Hatch merges their branches
/// in order into a branch of its own, in its own worktree, so the owner's checkout and the ticket workspaces stay untouched.
public final class PreviewBuilder: @unchecked Sendable {
    public let workspaces: WorkspaceManager
    var store: HatchStore { workspaces.store }
    var git: GitRunner { workspaces.git }

    public init(workspaces: WorkspaceManager) { self.workspaces = workspaces }

    public static func displayName(_ number: Int) -> String { "Preview " + (number < 10 ? "0\(number)" : "\(number)") }
    public static func branchName(_ number: Int) -> String { "preview/" + (number < 10 ? "0\(number)" : "\(number)") }

    /// Merges the tickets' branches (in the order given) with `--no-ff` into a new preview branch.
    /// Every ticket needs a workspace in `repo`. On a conflict the preview worktree and branch are removed again.
    public func build(repo: Repo, tickets: [Ticket]) throws -> PreviewResult {
        let repoDir = try workspaces.repoPath(repo)
        var branches: [(ticket: Ticket, branch: String)] = []
        for t in tickets {
            guard let ws = try store.workspace(ticketId: t.id, repoId: repo.id), ws.state == "active" else {
                throw GitError.invalid("\(t.displayNumber) has no workspace in this repo, so it cannot go into a Preview.")
            }
            branches.append((t, ws.branch))
        }
        let number = try store.nextPreviewNumber()
        let branch = Self.branchName(number)
        let preview = try store.createPreview(name: Self.displayName(number), branch: branch, ticketIds: tickets.map(\.id))
        let root = try workspaces.workspaceRoot(for: repo)
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        let repoName = URL(fileURLWithPath: repoDir).lastPathComponent
        let path = URL(fileURLWithPath: root).appendingPathComponent("\(repoName)-\(branch.replacingOccurrences(of: "/", with: "-"))").path

        let start = try git.resolve(git.tip(of: repo.defaultBranch, repo: repoDir), in: repoDir)
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        try git.git(["worktree", "add", "--no-track", "-B", branch, path, start], in: repoDir)

        var log = "Preview \(number) from \(repo.defaultBranch) @ \(start.prefix(8))\n"
        var merged: [Int] = []
        for (t, b) in branches {
            let r = try git.run(["merge", "--no-ff", "--no-edit", "-m", "Merge \(t.displayNumber) into \(branch)", b], in: path)
            if r.ok { merged.append(t.id); log += "merged \(t.displayNumber) (\(b))\n"; continue }
            let treeFiles = git.conflictedFiles(in: path)
            if treeFiles.isEmpty { // not a conflict: a real failure; clean up and report
                cleanup(path: path, branch: branch, repoDir: repoDir)
                try store.setPreview(preview.id, state: "conflict", log: log + "failed: \(r.stderr)")
                throw GitError.failed(args: ["merge", b], exitCode: r.exitCode, stderr: r.stderr)
            }
            let earlier = Array(branches.prefix(merged.count))
            let conflict = findPair(repoDir: repoDir, root: root, later: (t, b), earlier: earlier, fallbackFiles: treeFiles)
            cleanup(path: path, branch: branch, repoDir: repoDir)
            log += "CONFLICT \(t.displayNumber) with \(tickets.first { $0.id == conflict.againstTicketId }?.displayNumber ?? "earlier tickets"): \(conflict.files.joined(separator: ", "))\n"
            try store.setPreview(preview.id, state: "conflict", log: log)
            return PreviewResult(preview: try store.preview(id: preview.id)!, worktreePath: nil, mergedTicketIds: merged, conflict: conflict)
        }
        try store.setPreview(preview.id, state: "merged", log: log)
        return PreviewResult(preview: try store.preview(id: preview.id)!, worktreePath: path, mergedTicketIds: merged, conflict: nil)
    }

    /// Removes the preview's worktree and branch (the Preview is throwaway). The row stays, marked discarded.
    public func discard(_ preview: Preview, repo: Repo) throws {
        let repoDir = try workspaces.repoPath(repo)
        if let b = preview.branch {
            var current: String?
            for line in (try? git.lines(["worktree", "list", "--porcelain"], in: repoDir)) ?? [] {
                if line.hasPrefix("worktree ") { current = String(line.dropFirst(9)) }
                else if line == "branch refs/heads/\(b)", let p = current { git.run_ignoringFailure(["worktree", "remove", "--force", p], in: repoDir) }
            }
        }
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        if let b = preview.branch, git.branchExists(b, in: repoDir) { try git.git(["branch", "-D", b], in: repoDir) }
        try store.setPreview(preview.id, state: "discarded")
    }

    private func cleanup(path: String, branch: String, repoDir: String) {
        git.run_ignoringFailure(["merge", "--abort"], in: path)
        git.run_ignoringFailure(["worktree", "remove", "--force", path], in: repoDir)
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        git.run_ignoringFailure(["branch", "-D", branch], in: repoDir)
    }

    /// Tests the later branch against each earlier one alone (scratch merges in a detached worktree) to name the real pair.
    /// If no single earlier branch conflicts (the clash needs the combination), blames the nearest earlier ticket.
    private func findPair(repoDir: String, root: String, later: (ticket: Ticket, branch: String), earlier: [(ticket: Ticket, branch: String)], fallbackFiles: [String]) -> PreviewConflict {
        let choices: [ConflictChoice] = [.drop, .stack, .askAgentToResolve]
        func conflict(_ against: (ticket: Ticket, branch: String), _ files: [String]) -> PreviewConflict {
            PreviewConflict(ticketId: later.ticket.id, againstTicketId: against.ticket.id, branch: later.branch, againstBranch: against.branch, files: files, choices: choices)
        }
        guard let nearest = earlier.last else { return PreviewConflict(ticketId: later.ticket.id, againstTicketId: later.ticket.id, branch: later.branch, againstBranch: later.branch, files: fallbackFiles, choices: choices) }
        let scratch = URL(fileURLWithPath: root).appendingPathComponent(".scratch-\(UUID().uuidString.prefix(8))").path
        guard git.succeeds(["worktree", "add", "--detach", scratch, earlier[0].branch], in: repoDir) else { return conflict(nearest, fallbackFiles) }
        defer {
            git.run_ignoringFailure(["worktree", "remove", "--force", scratch], in: repoDir)
            git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        }
        for e in earlier {
            git.run_ignoringFailure(["merge", "--abort"], in: scratch)
            guard git.succeeds(["reset", "--hard", "--quiet", e.branch], in: scratch) else { continue }
            if let r = try? git.run(["merge", "--no-commit", "--no-ff", later.branch], in: scratch), !r.ok {
                let files = git.conflictedFiles(in: scratch)
                if !files.isEmpty { return conflict(e, files) }
            }
        }
        return conflict(nearest, fallbackFiles)
    }
}
