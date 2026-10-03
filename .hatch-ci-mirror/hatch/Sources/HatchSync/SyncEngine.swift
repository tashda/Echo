import Foundation
import HatchCore

public struct PushSummary: Equatable, Sendable {
    public var done = 0
    public var failed = 0
    /// Left pending on purpose: waiting for the issue to be created, or the run stopped at the rate limit.
    public var skipped = 0
}

public struct PullSummary: Equatable, Sendable {
    public var issuesSeen = 0
    public var created = 0
    public var textUpdated = 0
    public var comments = 0
    public var drifts = 0
}

public enum CIState: Equatable, Sendable {
    case pending
    case passed
    case failed([String])
}

/// Drains the queue to GitHub and reads GitHub back (decision rule: the app does the bookkeeping, agents never touch GitHub).
/// Decision M1: Hatch owns status, GitHub owns text.
public final class SyncEngine {
    public let store: HatchStore
    public let tracker: IssueTracker
    private var ensured: [String: Set<String>] = [:]

    public init(store: HatchStore, tracker: IssueTracker) {
        self.store = store; self.tracker = tracker
    }

    // MARK: Push

    /// Sends due operations in id order. Safe to run repeatedly: finished operations are marked done and never sent again.
    @discardableResult
    public func pushPending(repo: String, limit: Int = 50) throws -> PushSummary {
        var summary = PushSummary()
        let ops = try store.pendingSync(limit: limit)
        for (index, op) in ops.enumerated() {
            do {
                if try push(op, repo: repo) { try store.markSyncDone(op.id); summary.done += 1 } else { summary.skipped += 1 }
            } catch let e as TrackerError {
                try store.markSyncFailed(op.id, error: e.description, maxAttempts: e.isRetryable ? 8 : 1)
                summary.failed += 1
                // Every later call would hit the same wall.
                if case .rateLimited = e { summary.skipped += ops.count - index - 1; break }
            } catch {
                try store.markSyncFailed(op.id, error: "\(error)")
                summary.failed += 1
            }
        }
        return summary
    }

    /// Returns false when the operation must wait (its issue does not exist yet).
    private func push(_ op: SyncOp, repo: String) throws -> Bool {
        guard let ticketId = op.ticketId, let ticket = try store.ticket(id: ticketId) else {
            throw TrackerError.validation("Operation \(op.id) (\(op.op)) has no ticket")
        }
        if op.op == "issue.create" {
            if ticket.ghNumber != nil { return true }
            let labels = (op.payload["labels"]?.arrayValue ?? []).compactMap { $0.stringValue }
            try ensureLabels(repo: repo, labels)
            let issue = try tracker.createIssue(repo: repo, title: op.payload["title"]?.stringValue ?? ticket.title,
                                                body: op.payload["body"]?.stringValue ?? ticket.body, labels: labels)
            try store.applyIssueCreated(ticketId: ticketId, ghNumber: issue.number, updatedAt: GitHubDate.string(issue.updatedAt))
            return true
        }
        guard let number = ticket.ghNumber else { return false }
        switch op.op {
        case "issue.update":
            try tracker.updateIssue(repo: repo, number: number, title: op.payload["title"]?.stringValue, body: op.payload["body"]?.stringValue)
        case "issue.labels":
            let labels = (op.payload["labels"]?.arrayValue ?? []).compactMap { $0.stringValue }
            try ensureLabels(repo: repo, labels)
            try tracker.setLabels(repo: repo, number: number, labels: labels)
        case "issue.comment":
            let id = try tracker.addComment(repo: repo, number: number, body: op.payload["body"]?.stringValue ?? "")
            if let noteId = op.payload["note"]?.intValue { try store.setGhCommentId(noteId: noteId, commentId: id) }
        case "issue.close":
            try tracker.closeIssue(repo: repo, number: number, reason: op.payload["reason"]?.stringValue ?? "completed")
        case "issue.reopen":
            try tracker.reopenIssue(repo: repo, number: number)
        default:
            throw TrackerError.validation("Unknown operation \(op.op)")
        }
        return true
    }

    /// Creates the labels Hatch uses before they are first applied. Cached per repo for the life of the engine.
    private func ensureLabels(repo: String, _ labels: [String]) throws {
        var known = ensured[repo] ?? []
        var needed = Set(labels)
        if known.isEmpty { needed.formUnion(LabelSpec.baseSet.map(\.name)) }
        let missing = needed.subtracting(known)
        guard !missing.isEmpty else { return }
        try tracker.ensureLabels(repo: repo, missing.sorted().map(LabelSpec.hatch))
        known.formUnion(missing)
        ensured[repo] = known
    }

    // MARK: Pull

    private func cursorKey(_ repo: String) -> String { "sync.pull.\(repo)" }

    /// Reads issues changed since the last pull. Text and new comments come in; status never does (drift is flagged instead).
    @discardableResult
    public func pull(repo: String, projectId: Int, since: Date? = nil) throws -> PullSummary {
        var summary = PullSummary()
        let cursor = try since ?? store.setting(cursorKey(repo)).flatMap(GitHubDate.parse)
        do {
            let issues = try tracker.listIssues(repo: repo, since: cursor).filter { !$0.isPullRequest }
            var newest = cursor
            for issue in issues {
                summary.issuesSeen += 1
                try apply(issue, repo: repo, projectId: projectId, since: cursor, into: &summary)
                if newest == nil || issue.updatedAt > newest! { newest = issue.updatedAt }
            }
            if let newest { try store.setSetting(cursorKey(repo), GitHubDate.string(newest)) }
            try store.logPull(summary: "\(repo): \(summary.issuesSeen) issues, \(summary.created) new, \(summary.textUpdated) edited, \(summary.comments) comments, \(summary.drifts) drift", ok: true)
            return summary
        } catch {
            try? store.logPull(summary: "\(repo): pull failed", ok: false, error: "\(error)")
            throw error
        }
    }

    private func apply(_ issue: RemoteIssue, repo: String, projectId: Int, since: Date?, into s: inout PullSummary) throws {
        var ticket: Ticket
        if let known = try store.ticket(ghNumber: issue.number) {
            ticket = known
            let pending = try store.pendingOps(ticketId: ticket.id).map(\.op)
            // A local edit still waiting to go out wins over the older text on GitHub.
            if !pending.contains("issue.update") && !pending.contains("issue.create") {
                let before = ticket
                try store.applyRemoteText(ticketId: ticket.id, title: issue.title, body: issue.body)
                if let after = try store.ticket(id: ticket.id), after.title != before.title || after.body != before.body { s.textUpdated += 1; ticket = after }
            }
            s.drifts += try flagDrift(ticket, issue, pending: pending)
        } else {
            ticket = try importIssue(issue, projectId: projectId)
            s.created += 1
        }
        try store.setGhUpdatedAt(ticketId: ticket.id, GitHubDate.string(issue.updatedAt))
        if issue.commentsCount > 0 { s.comments += try importComments(issue, repo: repo, ticket: ticket, since: since) }
    }

    /// A ticket made on the phone: it already exists on GitHub, so it is never a Draft and nothing is queued back.
    private func importIssue(_ issue: RemoteIssue, projectId: Int) throws -> Ticket {
        let type = issue.labels.first { $0.hasPrefix("type:") }.flatMap { TicketType(rawValue: String($0.dropFirst(5))) } ?? .question
        var status: Status = .checking
        if issue.isClosed { status = .done }
        else if let l = issue.labels.first(where: { $0.hasPrefix("status:") }), let st = Status(rawValue: String(l.dropFirst(7))) { status = st }
        var pid = projectId
        if let l = issue.labels.first(where: { $0.hasPrefix("project:") }), let p = try store.project(key: String(l.dropFirst(8))) { pid = p.id }
        let area = issue.labels.first { $0.hasPrefix("area:") }.map { String($0.dropFirst(5)) }
        let t = try store.createTicket(projectId: pid, type: type, title: issue.title, body: issue.body, area: area, ghNumber: issue.number, status: status, actor: .hatch)
        try store.record(t.id, actor: "github", kind: "imported", payload: ["issue": .int(issue.number)])
        return t
    }

    /// Status on GitHub that disagrees with Hatch is recorded, and Hatch's value is queued to be written back.
    private func flagDrift(_ t: Ticket, _ issue: RemoteIssue, pending: [String]) throws -> Int {
        var found = 0
        let statusLabels = issue.labels.filter { $0.hasPrefix("status:") }
        if !statusLabels.isEmpty, !statusLabels.contains(t.status.label), !pending.contains("issue.labels"), !pending.contains("issue.create") {
            try store.record(t.id, actor: "github", kind: "status-drift", payload: ["github": .string(statusLabels[0]), "hatch": .string(t.status.label)])
            try store.enqueueLabels(t.id)
            found += 1
        }
        if issue.isClosed, !t.status.isTerminal, !pending.contains("issue.close") {
            let payload: JSONValue = ["github": "closed", "hatch": .string(t.status.label)]
            let last = try store.events(ticketId: t.id, kinds: ["status-drift", "status"]).last
            if !(last?.kind == "status-drift" && last?.payload == payload) {
                try store.record(t.id, actor: "github", kind: "status-drift", payload: payload)
                found += 1
            }
        }
        return found
    }

    private func importComments(_ issue: RemoteIssue, repo: String, ticket: Ticket, since: Date?) throws -> Int {
        var n = 0
        for c in try tracker.listComments(repo: repo, number: issue.number, since: since) {
            if try store.hasGhComment(ticketId: ticket.id, commentId: c.id) || Self.isHatchComment(c.body) { continue }
            let text = c.body.trimmingCharacters(in: .whitespacesAndNewlines)
            if text.isEmpty { continue }
            try store.addNote(ticket.id, kind: .comment, author: c.author, body: text, ghCommentId: c.id, at: c.createdAt)
            n += 1
        }
        return n
    }

    /// Comments Hatch posted start with a bold header line, then a blank line (`HatchStore.commentBody`).
    static func isHatchComment(_ body: String) -> Bool {
        let lines = body.split(separator: "\n", maxSplits: 2, omittingEmptySubsequences: false)
        guard lines.count >= 2, let first = lines.first else { return false }
        let h = first.trimmingCharacters(in: .whitespaces)
        return h.count > 4 && h.hasPrefix("**") && h.hasSuffix("**") && lines[1].trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: CI and attachments

    /// Aggregates check runs on the integration branch (decision I6). A failure is reported as soon as one run fails.
    public func ciStatus(repo: String, ref: String) throws -> CIState {
        let runs = try tracker.checkRuns(repo: repo, ref: ref)
        let bad: Set<String> = ["failure", "timed_out", "cancelled", "action_required", "startup_failure", "stale"]
        let failed = runs.filter { $0.status == "completed" && bad.contains($0.conclusion ?? "") }.map(\.name)
        if !failed.isEmpty { return .failed(failed) }
        if runs.isEmpty || runs.contains(where: { $0.status != "completed" }) { return .pending }
        return .passed
    }

    /// Commits a screenshot to `attachments/<ticket number>/<name>` in the tickets repo (decision M3) and records it.
    @discardableResult
    public func commitAttachment(ticket: Ticket, localFile: URL, repo: String, branch: String = "main", caption: String? = nil) throws -> Attachment {
        let data = try Data(contentsOf: localFile)
        let folder = ticket.ghNumber.map(String.init) ?? "new-\(ticket.id)"
        let path = "attachments/\(folder)/\(localFile.lastPathComponent)"
        let sha = try tracker.putFile(repo: repo, path: path, data: data, message: "Add \(localFile.lastPathComponent) to \(ticket.displayNumber)", branch: branch)
        return try store.addAttachment(ticket.id, path: path, sha: sha, kind: "screenshot", caption: caption)
    }
}
