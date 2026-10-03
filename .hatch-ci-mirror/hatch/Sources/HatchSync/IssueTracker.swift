import Foundation
import HatchCore

/// An issue as GitHub reports it. Only the fields Hatch uses.
public struct RemoteIssue: Equatable, Sendable {
    public var number: Int
    public var title: String
    public var body: String
    public var state: String            // "open" or "closed"
    public var labels: [String]
    public var updatedAt: Date
    public var commentsCount: Int
    /// GitHub lists pull requests as issues; the engine skips them.
    public var isPullRequest: Bool

    public init(number: Int, title: String, body: String = "", state: String = "open", labels: [String] = [],
                updatedAt: Date = Date(), commentsCount: Int = 0, isPullRequest: Bool = false) {
        self.number = number; self.title = title; self.body = body; self.state = state; self.labels = labels
        self.updatedAt = updatedAt; self.commentsCount = commentsCount; self.isPullRequest = isPullRequest
    }
    public var isClosed: Bool { state == "closed" }
}

public struct RemoteComment: Equatable, Sendable {
    public var id: Int
    public var body: String
    public var author: String
    public var createdAt: Date
    public init(id: Int, body: String, author: String, createdAt: Date = Date()) {
        self.id = id; self.body = body; self.author = author; self.createdAt = createdAt
    }
}

public struct LabelSpec: Equatable, Sendable {
    public var name: String
    public var color: String            // hex without '#'
    public var description: String
    public init(name: String, color: String, description: String = "") {
        self.name = name; self.color = color; self.description = description
    }

    /// Status labels take the colour of whose turn it is, so the label list reads like the Desk.
    public static func hatch(_ name: String) -> LabelSpec {
        if name.hasPrefix("status:"), let s = Status(rawValue: String(name.dropFirst(7))) {
            let color: String
            switch s.turn {
            case .you: color = "F0A25E"
            case .agent: color = "4FC3D4"
            case .hatch: color = "93A1B8"
            case .finished: color = "6CCB8A"
            case .paused: color = "8697AB"
            }
            return LabelSpec(name: name, color: color, description: "Hatch status: \(s.displayName)")
        }
        if name.hasPrefix("type:") { return LabelSpec(name: name, color: "B49AE6", description: "Hatch ticket type") }
        if name.hasPrefix("project:") { return LabelSpec(name: name, color: "6E7B91", description: "Hatch project") }
        return LabelSpec(name: name, color: "8697AB", description: "Hatch area")
    }

    /// Every type and status label, created once per repo before the first label is used.
    public static var baseSet: [LabelSpec] {
        TicketType.allCases.map { hatch($0.label) } + Status.allCases.map { hatch($0.label) }
    }
}

public struct CheckRun: Equatable, Sendable {
    public var name: String
    public var status: String           // queued, in_progress, completed
    public var conclusion: String?      // success, failure, ...
    public init(name: String, status: String, conclusion: String? = nil) {
        self.name = name; self.status = status; self.conclusion = conclusion
    }
}

public enum TrackerError: Error, CustomStringConvertible, Equatable {
    case noToken
    case unauthorized
    case notFound(String)
    case validation(String)
    case rateLimited(resetAt: Date?)
    case http(status: Int, message: String)
    case transport(String)

    /// Worth trying again later. Validation and not-found errors will not fix themselves.
    public var isRetryable: Bool {
        switch self {
        case .rateLimited, .transport: return true
        case .http(let status, _): return status >= 500 || status == 408
        case .noToken, .unauthorized, .notFound, .validation: return false
        }
    }

    public var description: String {
        switch self {
        case .noToken: return "No GitHub token (set GITHUB_TOKEN or run gh auth login)"
        case .unauthorized: return "GitHub rejected the token (401)"
        case .notFound(let m): return "Not found on GitHub: \(m)"
        case .validation(let m): return "GitHub refused the request (422): \(m)"
        case .rateLimited(let reset):
            return "GitHub rate limit reached" + (reset.map { ", resets at \(GitHubDate.string($0))" } ?? "")
        case .http(let s, let m): return "GitHub error \(s): \(m)"
        case .transport(let m): return "Network error: \(m)"
        }
    }
}

/// Labels Hatch manages. Everything else on an issue belongs to people and is never touched.
public func isHatchManagedLabel(_ label: String) -> Bool {
    ["type:", "status:", "project:", "area:"].contains { label.hasPrefix($0) }
}

/// The GitHub operations Hatch needs, synchronous so the queue drain is easy to reason about.
/// A protocol so tests and `hatch --dry-run` use `InMemoryTracker` and never touch the network.
public protocol IssueTracker: AnyObject {
    func createIssue(repo: String, title: String, body: String, labels: [String]) throws -> RemoteIssue
    func updateIssue(repo: String, number: Int, title: String?, body: String?) throws
    /// Replaces the Hatch-managed labels (type:, status:, project:, area:); other labels stay.
    func setLabels(repo: String, number: Int, labels: [String]) throws
    func addComment(repo: String, number: Int, body: String) throws -> Int
    func closeIssue(repo: String, number: Int, reason: String) throws
    func reopenIssue(repo: String, number: Int) throws
    func listIssues(repo: String, since: Date?) throws -> [RemoteIssue]
    func listComments(repo: String, number: Int, since: Date?) throws -> [RemoteComment]
    func ensureLabels(repo: String, _ labels: [LabelSpec]) throws
    /// Commits a file (screenshots, decision M3). Returns the content sha.
    @discardableResult
    func putFile(repo: String, path: String, data: Data, message: String, branch: String) throws -> String
    func checkRuns(repo: String, ref: String) throws -> [CheckRun]
}

enum GitHubDate {
    static func string(_ d: Date) -> String {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }
    static func parse(_ s: String?) -> Date? {
        guard let s else { return nil }
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: s)
    }
}

// MARK: - In-memory tracker

/// A faithful fake of GitHub: numbers increment, labels and comments are kept, failures can be injected.
public final class InMemoryTracker: IssueTracker, @unchecked Sendable {
    public struct Stored {
        public var issue: RemoteIssue
        public var comments: [RemoteComment] = []
    }

    private let lock = NSRecursiveLock()
    public var clock: () -> Date
    public private(set) var issues: [String: [Int: Stored]] = [:]
    public private(set) var knownLabels: [String: [String: LabelSpec]] = [:]
    public private(set) var files: [String: Data] = [:]      // "repo/path"
    public private(set) var calls: [String] = []              // "createIssue", "setLabels#3", ...
    public var checkRunsByRef: [String: [CheckRun]] = [:]
    private var nextNumber: Int
    private var nextCommentId = 9000
    private var failuresLeft = 0
    private var failure: TrackerError = .transport("offline")
    public var login = "owner"

    public init(firstNumber: Int = 1, clock: @escaping () -> Date = { Date() }) {
        self.nextNumber = firstNumber; self.clock = clock
    }

    /// The next `count` calls throw `error`, then calls succeed again.
    public func failNext(_ count: Int, error: TrackerError = .transport("offline")) {
        lock.lock(); defer { lock.unlock() }
        failuresLeft = count; failure = error
    }

    private func enter(_ name: String) throws {
        lock.lock(); defer { lock.unlock() }
        calls.append(name)
        if failuresLeft > 0 { failuresLeft -= 1; throw failure }
    }

    public func issue(_ repo: String, _ number: Int) -> RemoteIssue? {
        lock.lock(); defer { lock.unlock() }
        return issues[repo]?[number]?.issue
    }

    public func comments(_ repo: String, _ number: Int) -> [RemoteComment] {
        lock.lock(); defer { lock.unlock() }
        return issues[repo]?[number]?.comments ?? []
    }

    public func callCount(_ prefix: String) -> Int { calls.filter { $0.hasPrefix(prefix) }.count }

    // Things a person does on github.com or on the phone.

    @discardableResult
    public func seedIssue(repo: String, title: String, body: String = "", labels: [String] = [], state: String = "open") -> RemoteIssue {
        lock.lock(); defer { lock.unlock() }
        let n = nextNumber; nextNumber += 1
        let issue = RemoteIssue(number: n, title: title, body: body, state: state, labels: labels, updatedAt: clock())
        issues[repo, default: [:]][n] = Stored(issue: issue)
        return issue
    }

    public func humanEdit(repo: String, number: Int, title: String? = nil, body: String? = nil, labels: [String]? = nil, state: String? = nil) {
        lock.lock(); defer { lock.unlock() }
        guard var s = issues[repo]?[number] else { return }
        if let title { s.issue.title = title }
        if let body { s.issue.body = body }
        if let labels { s.issue.labels = labels }
        if let state { s.issue.state = state }
        s.issue.updatedAt = clock()
        issues[repo]?[number] = s
    }

    @discardableResult
    public func humanComment(repo: String, number: Int, body: String, author: String = "owner") -> Int {
        lock.lock(); defer { lock.unlock() }
        let id = nextCommentId; nextCommentId += 1
        issues[repo]?[number]?.comments.append(RemoteComment(id: id, body: body, author: author, createdAt: clock()))
        issues[repo]?[number]?.issue.commentsCount += 1
        issues[repo]?[number]?.issue.updatedAt = clock()
        return id
    }

    // IssueTracker

    public func createIssue(repo: String, title: String, body: String, labels: [String]) throws -> RemoteIssue {
        try enter("createIssue")
        lock.lock(); defer { lock.unlock() }
        let n = nextNumber; nextNumber += 1
        let issue = RemoteIssue(number: n, title: title, body: body, state: "open", labels: labels, updatedAt: clock())
        issues[repo, default: [:]][n] = Stored(issue: issue)
        return issue
    }

    public func updateIssue(repo: String, number: Int, title: String?, body: String?) throws {
        try enter("updateIssue#\(number)")
        lock.lock(); defer { lock.unlock() }
        guard var s = issues[repo]?[number] else { throw TrackerError.notFound("issue #\(number)") }
        if let title { s.issue.title = title }
        if let body { s.issue.body = body }
        s.issue.updatedAt = clock()
        issues[repo]?[number] = s
    }

    public func setLabels(repo: String, number: Int, labels: [String]) throws {
        try enter("setLabels#\(number)")
        lock.lock(); defer { lock.unlock() }
        guard var s = issues[repo]?[number] else { throw TrackerError.notFound("issue #\(number)") }
        s.issue.labels = s.issue.labels.filter { !isHatchManagedLabel($0) } + labels.filter(isHatchManagedLabel)
        s.issue.updatedAt = clock()
        issues[repo]?[number] = s
    }

    public func addComment(repo: String, number: Int, body: String) throws -> Int {
        try enter("addComment#\(number)")
        lock.lock(); defer { lock.unlock() }
        guard issues[repo]?[number] != nil else { throw TrackerError.notFound("issue #\(number)") }
        let id = nextCommentId; nextCommentId += 1
        issues[repo]?[number]?.comments.append(RemoteComment(id: id, body: body, author: login, createdAt: clock()))
        issues[repo]?[number]?.issue.commentsCount += 1
        issues[repo]?[number]?.issue.updatedAt = clock()
        return id
    }

    public func closeIssue(repo: String, number: Int, reason: String) throws {
        try enter("closeIssue#\(number)")
        lock.lock(); defer { lock.unlock() }
        guard issues[repo]?[number] != nil else { throw TrackerError.notFound("issue #\(number)") }
        issues[repo]?[number]?.issue.state = "closed"
        issues[repo]?[number]?.issue.updatedAt = clock()
    }

    public func reopenIssue(repo: String, number: Int) throws {
        try enter("reopenIssue#\(number)")
        lock.lock(); defer { lock.unlock() }
        guard issues[repo]?[number] != nil else { throw TrackerError.notFound("issue #\(number)") }
        issues[repo]?[number]?.issue.state = "open"
        issues[repo]?[number]?.issue.updatedAt = clock()
    }

    public func listIssues(repo: String, since: Date?) throws -> [RemoteIssue] {
        try enter("listIssues")
        lock.lock(); defer { lock.unlock() }
        return (issues[repo] ?? [:]).values.map(\.issue).filter { since == nil || $0.updatedAt >= since! }.sorted { $0.number < $1.number }
    }

    public func listComments(repo: String, number: Int, since: Date?) throws -> [RemoteComment] {
        try enter("listComments#\(number)")
        lock.lock(); defer { lock.unlock() }
        return (issues[repo]?[number]?.comments ?? []).filter { since == nil || $0.createdAt >= since! }
    }

    public func ensureLabels(repo: String, _ labels: [LabelSpec]) throws {
        try enter("ensureLabels")
        lock.lock(); defer { lock.unlock() }
        for l in labels where knownLabels[repo]?[l.name] == nil { knownLabels[repo, default: [:]][l.name] = l }
    }

    public func putFile(repo: String, path: String, data: Data, message: String, branch: String) throws -> String {
        try enter("putFile")
        lock.lock(); defer { lock.unlock() }
        files["\(repo)/\(path)"] = data
        return "sha-\(data.count)"
    }

    public func checkRuns(repo: String, ref: String) throws -> [CheckRun] {
        try enter("checkRuns")
        lock.lock(); defer { lock.unlock() }
        return checkRunsByRef[ref] ?? []
    }
}
