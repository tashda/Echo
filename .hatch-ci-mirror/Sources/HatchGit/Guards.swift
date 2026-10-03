import Foundation
import HatchCore

/// What an agent may push: only its own ticket branch (decision K). Exposed as data so the app can show it.
public struct GuardPolicy: Equatable, Sendable {
    public let ticketToken: String
    /// Short branch pattern for display, e.g. `ticket/151-*`.
    public var allowedBranchPattern: String { "ticket/\(ticketToken)-*" }

    public init(ticketToken: String) { self.ticketToken = ticketToken }
    public init(ticket: Ticket) { self.ticketToken = WorkspaceManager.ticketToken(ticket) }

    /// True when pushing to this full remote ref (`refs/heads/...`) is allowed.
    public func allows(remoteRef: String) -> Bool {
        remoteRef == "refs/heads/ticket/\(ticketToken)" || remoteRef.hasPrefix("refs/heads/ticket/\(ticketToken)-")
    }

    public var summary: String { "Agents may push only to \(allowedBranchPattern); everything else, including the default branch and tags, is refused." }

    /// The pre-push script. Git feeds it `<local ref> <local sha> <remote ref> <remote sha>` lines on stdin.
    var hookScript: String {
        """
        #!/bin/sh
        # Installed by Hatch. Agents may only push their own ticket branch (\(allowedBranchPattern)).
        while read local_ref local_sha remote_ref remote_sha; do
          case "$remote_ref" in
            refs/heads/ticket/\(ticketToken)|refs/heads/ticket/\(ticketToken)-*) ;;
            *)
              echo "Hatch: push to $remote_ref refused. This workspace may only push \(allowedBranchPattern)." >&2
              exit 1
              ;;
          esac
        done
        exit 0

        """
    }
}

public extension WorkspaceManager {
    /// Writes the pre-push hook into a hooks folder private to this worktree and points only this worktree at it
    /// (`extensions.worktreeConfig` + `git config --worktree core.hooksPath`), so the main checkout and other
    /// workspaces keep their own hooks.
    func installGuards(_ ws: Workspace) throws {
        guard let ticket = try store.ticket(id: ws.ticketId) else { throw StoreError.notFound("ticket \(ws.ticketId)") }
        let policy = GuardPolicy(ticket: ticket)
        let gitDir = try git.git(["rev-parse", "--absolute-git-dir"], in: ws.path)
        let hooks = URL(fileURLWithPath: gitDir).appendingPathComponent("hatch-hooks")
        try FileManager.default.createDirectory(at: hooks, withIntermediateDirectories: true)
        let hook = hooks.appendingPathComponent("pre-push")
        try policy.hookScript.write(to: hook, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: hook.path)
        try git.git(["config", "extensions.worktreeConfig", "true"], in: ws.path)
        try git.git(["config", "--worktree", "core.hooksPath", hooks.path], in: ws.path)
    }

    func guardsInstalled(_ ws: Workspace) -> Bool {
        guard let p = try? git.git(["config", "--worktree", "--get", "core.hooksPath"], in: ws.path) else { return false }
        return FileManager.default.isExecutableFile(atPath: URL(fileURLWithPath: p).appendingPathComponent("pre-push").path)
    }

    func guardPolicy(for ws: Workspace) throws -> GuardPolicy {
        guard let ticket = try store.ticket(id: ws.ticketId) else { throw StoreError.notFound("ticket \(ws.ticketId)") }
        return GuardPolicy(ticket: ticket)
    }
}
