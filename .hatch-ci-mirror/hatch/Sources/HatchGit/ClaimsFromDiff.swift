import Foundation
import HatchCore

/// Claimed files versus files actually changed (decision K3): a claim is a prediction, the diff is the truth.
public struct ClaimDrift: Equatable, Sendable {
    public let changedFiles: [String]
    public let claimedGlobs: [String]
    /// Changed files that no claim covers: the warning Hatch shows.
    public let unclaimedChanges: [String]
    /// Claimed globs that matched no changed file (informational).
    public let untouchedClaims: [String]
    public var hasDrift: Bool { !unclaimedChanges.isEmpty }
}

public struct ClaimsFromDiff: @unchecked Sendable {
    public let store: HatchStore
    public let git: GitRunner

    public init(store: HatchStore, git: GitRunner = ProcessGit()) { self.store = store; self.git = git }

    /// Every file that differs from the base: committed, staged, unstaged and untracked.
    public func changedFiles(_ ws: Workspace) throws -> [String] {
        let base = ws.baseSha ?? "HEAD"
        var files = Set(try git.lines(["diff", "--name-only", base], in: ws.path))
        files.formUnion(try git.lines(["ls-files", "--others", "--exclude-standard"], in: ws.path))
        return files.sorted()
    }

    /// Compares changed files with the ticket's live (not released) claims for the workspace's repo.
    public func claimDrift(ticketId: Int, workspace ws: Workspace) throws -> ClaimDrift {
        let globs = try store.claims(ticketId: ticketId).filter { $0.state != "released" && ($0.repoId == nil || $0.repoId == ws.repoId) }.map(\.pathGlob)
        let changed = try changedFiles(ws)
        let unclaimed = changed.filter { f in !globs.contains { Glob.matches($0, f) } }
        let untouched = globs.filter { g in !changed.contains { Glob.matches(g, $0) } }
        return ClaimDrift(changedFiles: changed, claimedGlobs: globs, unclaimedChanges: unclaimed, untouchedClaims: untouched)
    }

    public func claimDrift(_ ticket: Ticket, workspace ws: Workspace) throws -> ClaimDrift { try claimDrift(ticketId: ticket.id, workspace: ws) }
}
