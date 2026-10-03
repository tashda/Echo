import Foundation
import HatchCore

public struct WorkspaceStatus: Equatable, Sendable {
    public let branch: String
    public let headSha: String
    public let dirtyFiles: [String]
    public let commitsAhead: Int      // commits on the branch since its base sha
    public var isClean: Bool { dirtyFiles.isEmpty }
}

public enum MergeBaseResult: Equatable, Sendable {
    case upToDate
    case merged(sha: String)
    case conflicts([String])
}

/// One git worktree per ticket and repo, each on its own `ticket/<number>-<slug>` branch, so agents never share a working tree
/// and never touch the owner's main checkout (decision I1, K).
public final class WorkspaceManager: @unchecked Sendable {
    public let store: HatchStore
    public let git: GitRunner
    /// Where worktrees live. nil means `<repo parent>/.hatch-workspaces`.
    public var root: String?

    public init(store: HatchStore, git: GitRunner = ProcessGit(), root: String? = nil) {
        self.store = store; self.git = git; self.root = root
    }

    // MARK: Naming

    /// Lowercase, hyphenated, at most `maxLength` characters, never starting or ending with a hyphen.
    public static func slug(_ title: String, maxLength: Int = 40) -> String {
        var out = "", lastHyphen = true
        for ch in title.lowercased().unicodeScalars {
            if (ch.value >= 97 && ch.value <= 122) || (ch.value >= 48 && ch.value <= 57) { out.unicodeScalars.append(ch); lastHyphen = false }
            else if !lastHyphen { out.append("-"); lastHyphen = true }
        }
        var cut = String(out.prefix(maxLength))
        while cut.hasSuffix("-") { cut.removeLast() }
        return cut.isEmpty ? "ticket" : cut
    }

    /// `#151` becomes `151`; a ticket not yet on GitHub becomes `new-<id>`.
    public static func ticketToken(_ t: Ticket) -> String { t.ghNumber.map(String.init) ?? "new-\(t.id)" }

    public static func branchName(for t: Ticket) -> String { "ticket/\(ticketToken(t))-\(slug(t.title))" }

    public static func defaultRoot(forRepoPath path: String) -> String {
        URL(fileURLWithPath: path).deletingLastPathComponent().appendingPathComponent(".hatch-workspaces").path
    }

    func repoPath(_ repo: Repo) throws -> String {
        guard let p = repo.localPath, !p.isEmpty else { throw GitError.invalid("Repo \(repo.remote) has no local path.") }
        guard FileManager.default.fileExists(atPath: p) else { throw GitError.invalid("Repo path \(p) does not exist.") }
        return p
    }

    public func workspaceRoot(for repo: Repo) throws -> String { if let root { return root }; return Self.defaultRoot(forRepoPath: try repoPath(repo)) }

    public func path(for ticket: Ticket, repo: Repo) throws -> String {
        let name = URL(fileURLWithPath: try repoPath(repo)).lastPathComponent
        return URL(fileURLWithPath: try workspaceRoot(for: repo)).appendingPathComponent("\(name)-\(Self.ticketToken(ticket))").path
    }

    // MARK: Create, list, remove

    /// Creates the worktree and branch from the default branch tip, records the base sha and installs the push guard.
    /// Calling it again returns the existing workspace. Never touches the main checkout's working tree.
    @discardableResult
    public func create(ticket: Ticket, repo: Repo, installGuards guards: Bool = true) throws -> Workspace {
        let repoDir = try repoPath(repo)
        let path = try path(for: ticket, repo: repo)
        if let existing = try store.workspace(ticketId: ticket.id, repoId: repo.id), existing.state == "active",
           Self.samePath(existing.path, path), registeredWorktrees(repoDir).contains(where: { Self.samePath($0, path) }) {
            return existing
        }
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        try FileManager.default.createDirectory(atPath: try workspaceRoot(for: repo), withIntermediateDirectories: true)

        let branch = Self.branchName(for: ticket)
        let start = git.tip(of: repo.defaultBranch, repo: repoDir)
        let startSha = try git.resolve(start, in: repoDir)
        var base = startSha
        if registeredWorktrees(repoDir).contains(where: { Self.samePath($0, path) }) {
            // Row was lost but the worktree is still there: adopt it.
        } else if git.branchExists(branch, in: repoDir) {
            try git.git(["worktree", "add", path, branch], in: repoDir)
            base = (try? git.git(["merge-base", startSha, branch], in: repoDir)) ?? startSha
        } else {
            try git.git(["worktree", "add", "--no-track", "-b", branch, path, startSha], in: repoDir)
        }
        let ws = try store.saveWorkspace(ticketId: ticket.id, repoId: repo.id, path: path, branch: branch, baseSha: base)
        if guards { try installGuards(ws) }
        try store.record(ticket.id, actor: "hatch", kind: "workspace", payload: ["path": .string(path), "branch": .string(branch), "base": .string(base)])
        return ws
    }

    public func list(ticketId: Int? = nil) throws -> [Workspace] { try store.workspaces(ticketId: ticketId) }

    /// Removes the worktree. A dirty worktree is refused unless `force`. `deleteBranch` also deletes the ticket branch.
    public func remove(_ ws: Workspace, deleteBranch: Bool = false, force: Bool = false) throws {
        let repoDir = try mainRepoPath(ws)
        if FileManager.default.fileExists(atPath: ws.path) {
            try git.git(["worktree", "remove"] + (force ? ["--force"] : []) + [ws.path], in: repoDir)
        }
        git.run_ignoringFailure(["worktree", "prune"], in: repoDir)
        if deleteBranch, git.branchExists(ws.branch, in: repoDir) { try git.git(["branch", "-D", ws.branch], in: repoDir) }
        try store.setWorkspace(ws.id, state: "removed")
        try store.record(ws.ticketId, actor: "hatch", kind: "workspace-removed", payload: ["path": .string(ws.path), "branch": .string(ws.branch), "deletedBranch": .bool(deleteBranch)])
    }

    // MARK: Status and commits

    public func status(_ ws: Workspace) throws -> WorkspaceStatus {
        let out = try git.run(["status", "--porcelain=v1", "-z", "--untracked-files=all"], in: ws.path)
        guard out.ok else { throw GitError.failed(args: ["status"], exitCode: out.exitCode, stderr: out.stderr) }
        var files: [String] = []
        let entries = out.stdout.split(separator: "\0", omittingEmptySubsequences: true).map(String.init)
        var i = 0
        while i < entries.count {
            let e = entries[i]
            if e.count > 3 { files.append(String(e.dropFirst(3))) }
            if let c = e.first, c == "R" || c == "C" { i += 1 }    // rename entries carry the old name as a second record
            i += 1
        }
        let head = try git.git(["rev-parse", "HEAD"], in: ws.path)
        var ahead = 0
        if let base = ws.baseSha { ahead = Int(try git.git(["rev-list", "--count", "\(base)..HEAD"], in: ws.path)) ?? 0 }
        let branch = (try? git.git(["rev-parse", "--abbrev-ref", "HEAD"], in: ws.path)) ?? ws.branch
        return WorkspaceStatus(branch: branch, headSha: head, dirtyFiles: files.sorted(), commitsAhead: ahead)
    }

    /// Commits in the workspace (staging everything first when `all`). Returns the new sha, or nil when there was nothing to commit.
    @discardableResult
    public func commit(_ ws: Workspace, all: Bool = true, message: String) throws -> String? {
        if all { try git.git(["add", "-A"], in: ws.path) }
        if git.succeeds(["diff", "--cached", "--quiet"], in: ws.path) { return nil }
        try git.git(["commit", "--quiet", "-m", message], in: ws.path)
        return try git.git(["rev-parse", "HEAD"], in: ws.path)
    }

    /// Merges the default branch into the ticket branch so the ticket is current before it is declared done.
    /// On conflicts the merge is aborted (tree left clean) unless `leaveConflicts`, which keeps it open for an agent to resolve.
    public func mergeBaseIntoBranch(_ ws: Workspace, leaveConflicts: Bool = false) throws -> MergeBaseResult {
        guard let repo = try store.repo(id: ws.repoId) else { throw StoreError.notFound("repo \(ws.repoId)") }
        guard try status(ws).isClean else { throw GitError.invalid("Commit or stash changes in \(ws.path) before merging the base branch.") }
        let tip = git.tip(of: repo.defaultBranch, repo: ws.path)
        let tipSha = try git.resolve(tip, in: ws.path)
        if git.succeeds(["merge-base", "--is-ancestor", tipSha, "HEAD"], in: ws.path) { return .upToDate }
        let r = try git.run(["merge", "--no-edit", "-m", "Merge \(repo.defaultBranch) into \(ws.branch)", tipSha], in: ws.path)
        if r.ok {
            try store.setWorkspace(ws.id, baseSha: tipSha)
            return .merged(sha: try git.git(["rev-parse", "HEAD"], in: ws.path))
        }
        let files = git.conflictedFiles(in: ws.path)
        if files.isEmpty { throw GitError.failed(args: ["merge", tipSha], exitCode: r.exitCode, stderr: r.stderr) }
        if !leaveConflicts { git.run_ignoringFailure(["merge", "--abort"], in: ws.path) }
        return .conflicts(files)
    }

    // MARK: Helpers

    /// The main checkout that owns this worktree (so removal runs from outside the worktree being removed).
    func mainRepoPath(_ ws: Workspace) throws -> String {
        if let repo = try store.repo(id: ws.repoId), let p = repo.localPath { return p }
        throw GitError.invalid("Cannot find the main checkout for workspace \(ws.path).")
    }

    func registeredWorktrees(_ repoDir: String) -> [String] {
        ((try? git.lines(["worktree", "list", "--porcelain"], in: repoDir)) ?? []).compactMap {
            $0.hasPrefix("worktree ") ? String($0.dropFirst(9)) : nil
        }
    }

    static func samePath(_ a: String, _ b: String) -> Bool {
        URL(fileURLWithPath: a).resolvingSymlinksInPath().path == URL(fileURLWithPath: b).resolvingSymlinksInPath().path
    }
}

extension GitRunner {
    func run_ignoringFailure(_ args: [String], in dir: String?) { _ = try? run(args, in: dir) }
}
