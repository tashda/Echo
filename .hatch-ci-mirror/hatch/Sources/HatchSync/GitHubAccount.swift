import Foundation
import HatchCore

public struct GitHubUser: Equatable, Sendable {
    public var login: String
    public var name: String?
    public init(login: String, name: String? = nil) { self.login = login; self.name = name }
}

public struct GitHubRepoSummary: Equatable, Sendable, Identifiable {
    public var fullName: String            // "owner/name"
    public var isPrivate: Bool
    public var description: String?
    public var defaultBranch: String
    public var id: String { fullName }
    public init(fullName: String, isPrivate: Bool, description: String? = nil, defaultBranch: String = "main") {
        self.fullName = fullName; self.isPrivate = isPrivate; self.description = description; self.defaultBranch = defaultBranch
    }
}

/// Where the token in use comes from, for Settings. Order: stored by Hatch, `GITHUB_TOKEN`, the gh tool.
public enum GitHubTokenSource: Equatable, Sendable {
    case stored, environment, ghTool, none
}

/// What `GitHubClient.prepareTicketsRepo` did, so the app can tell the owner in plain words.
public struct TicketsRepoReport: Equatable, Sendable {
    public var repo: GitHubRepoSummary
    public var created: Bool
    public var labelsEnsured: Int
    /// A public tickets repository would expose private tickets: the app refuses to use it unless the owner insists.
    public var isPublic: Bool { !repo.isPrivate }
}

extension GitHubClient {
    static func summary(_ j: JSONValue) -> GitHubRepoSummary? {
        guard let full = j["full_name"]?.stringValue else { return nil }
        return GitHubRepoSummary(fullName: full, isPrivate: j["private"]?.boolValue ?? true,
                                 description: j["description"]?.stringValue, defaultBranch: j["default_branch"]?.stringValue ?? "main")
    }

    /// Who the token belongs to. Also proves the token works.
    public func currentUser() throws -> GitHubUser {
        let r = try perform("GET", url("/user"))
        let j = JSONValue.parse(String(decoding: r.body, as: UTF8.self))
        guard let login = j["login"]?.stringValue else { throw TrackerError.http(status: 200, message: "GitHub did not say who this token belongs to.") }
        return GitHubUser(login: login, name: j["name"]?.stringValue)
    }

    /// Repositories the token can use, most recently pushed first. Only the first `limit`, to keep the list quick.
    public func listRepositories(limit: Int = 100) throws -> [GitHubRepoSummary] {
        let r = try perform("GET", url("/user/repos", [("per_page", String(min(limit, 100))), ("sort", "pushed"),
                                                        ("affiliation", "owner,collaborator,organization_member")]))
        let arr = JSONValue.parse(String(decoding: r.body, as: UTF8.self)).arrayValue ?? []
        return arr.compactMap(Self.summary)
    }

    /// nil when the repository does not exist or the token cannot see it.
    public func repository(_ fullName: String) throws -> GitHubRepoSummary? {
        do {
            let r = try perform("GET", url(repoPath(fullName)))
            return Self.summary(JSONValue.parse(String(decoding: r.body, as: UTF8.self)))
        } catch TrackerError.notFound { return nil }
    }

    /// Creates a repository. Private unless told otherwise. With `organization`, in that organization instead of the user's account.
    public func createRepository(name: String, description: String, isPrivate: Bool = true, organization: String? = nil) throws -> GitHubRepoSummary {
        let path = organization.map { "/orgs/\($0)/repos" } ?? "/user/repos"
        let body: JSONValue = ["name": .string(name), "description": .string(description), "private": .bool(isPrivate), "auto_init": .bool(true)]
        let r = try perform("POST", url(path), body: body)
        guard let s = Self.summary(JSONValue.parse(String(decoding: r.body, as: UTF8.self))) else {
            throw TrackerError.http(status: 201, message: "GitHub created the repository but did not describe it.")
        }
        return s
    }

    /// Makes `fullName` ready to hold tickets: creates it (private) when missing and `createIfMissing`, then makes sure the Hatch labels exist.
    public func prepareTicketsRepo(_ fullName: String, createIfMissing: Bool) throws -> TicketsRepoReport {
        var created = false
        var found = try repository(fullName)
        if found == nil {
            guard createIfMissing else { throw TrackerError.notFound("\(fullName) does not exist, or this token cannot see it.") }
            let parts = fullName.split(separator: "/").map(String.init)
            guard parts.count == 2 else { throw TrackerError.validation("A repository is written owner/name.") }
            let me = try currentUser()
            found = try createRepository(name: parts[1], description: "Tickets for Hatch. Private on purpose.", isPrivate: true,
                                         organization: parts[0].lowercased() == me.login.lowercased() ? nil : parts[0])
            created = true
        }
        let labels = LabelSpec.baseSet.map { $0 }
        try ensureLabels(repo: fullName, labels)
        return TicketsRepoReport(repo: found!, created: created, labelsEnsured: labels.count)
    }

    /// Which source the token would come from right now, without using it.
    public static func tokenSource(stored: String?) -> GitHubTokenSource {
        if let stored, !stored.isEmpty { return .stored }
        if let env = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !env.isEmpty { return .environment }
        if let out = runGh(), !out.isEmpty { return .ghTool }
        return .none
    }
}
