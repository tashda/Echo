import Foundation
import HatchCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPRequest: Equatable, Sendable {
    public var method: String
    public var url: URL
    public var headers: [String: String]
    public var body: Data?
    public init(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil) {
        self.method = method; self.url = url; self.headers = headers; self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public var status: Int
    /// Header names lowercased.
    public var headers: [String: String]
    public var body: Data
    public init(status: Int, headers: [String: String] = [:], body: Data = Data()) {
        self.status = status
        self.headers = Dictionary(uniqueKeysWithValues: headers.map { ($0.key.lowercased(), $0.value) })
        self.body = body
    }
}

/// The only place the network is touched, so tests can hand the client canned responses.
public protocol HTTPTransport {
    func send(_ request: HTTPRequest) throws -> HTTPResponse
}

/// URLSession, blocking with a semaphore (works on Linux and macOS).
public struct URLSessionTransport: HTTPTransport {
    public var timeout: TimeInterval
    public init(timeout: TimeInterval = 30) { self.timeout = timeout }

    public func send(_ request: HTTPRequest) throws -> HTTPResponse {
        var r = URLRequest(url: request.url, timeoutInterval: timeout)
        r.httpMethod = request.method
        r.httpBody = request.body
        for (k, v) in request.headers { r.setValue(v, forHTTPHeaderField: k) }
        let box = ResultBox()
        let sem = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: r) { data, response, error in
            if let error { box.result = .failure(TrackerError.transport(error.localizedDescription)) }
            else if let http = response as? HTTPURLResponse {
                var headers: [String: String] = [:]
                for (k, v) in http.allHeaderFields { headers["\(k)"] = "\(v)" }
                box.result = .success(HTTPResponse(status: http.statusCode, headers: headers, body: data ?? Data()))
            } else { box.result = .failure(TrackerError.transport("no response")) }
            sem.signal()
        }.resume()
        sem.wait()
        return try box.result!.get()
    }

    private final class ResultBox: @unchecked Sendable { var result: Result<HTTPResponse, Error>? }
}

/// GitHub REST v3 behind `IssueTracker`.
public final class GitHubClient: IssueTracker, @unchecked Sendable {
    public let transport: HTTPTransport
    public let baseURL: String
    private var token: String?
    private let lock = NSLock()
    /// ETag and body per page URL, so an unchanged issue list costs no rate limit (a 304 is free).
    private var etags: [String: (etag: String, body: Data)] = [:]

    /// Token order: the parameter, `GITHUB_TOKEN`, then `gh auth token`.
    public init(token: String? = nil, transport: HTTPTransport = URLSessionTransport(), baseURL: String = "https://api.github.com") {
        self.token = token; self.transport = transport; self.baseURL = baseURL
    }

    func resolveToken() throws -> String {
        lock.lock(); defer { lock.unlock() }
        if let token, !token.isEmpty { return token }
        if let env = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !env.isEmpty { token = env; return env }
        if let out = Self.runGh(), !out.isEmpty { token = out; return out }
        throw TrackerError.noToken
    }

    private static func runGh() -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["gh", "auth", "token"]
        let pipe = Pipe()
        p.standardOutput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Requests

    func url(_ path: String, _ query: [(String, String)] = []) -> URL {
        var c = URLComponents(string: baseURL + path)!
        if !query.isEmpty { c.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        return c.url!
    }

    private func perform(_ method: String, _ url: URL, body: JSONValue? = nil, useETag: Bool = false) throws -> HTTPResponse {
        var headers = ["Authorization": "Bearer \(try resolveToken())", "Accept": "application/vnd.github+json",
                       "X-GitHub-Api-Version": "2022-11-28", "User-Agent": "Hatch"]
        if body != nil { headers["Content-Type"] = "application/json" }
        let key = url.absoluteString
        if useETag { lock.lock(); if let e = etags[key] { headers["If-None-Match"] = e.etag }; lock.unlock() }
        let req = HTTPRequest(method: method, url: url, headers: headers, body: body.map { Data($0.jsonString().utf8) })
        var resp = try transport.send(req)
        if resp.status == 304, useETag {
            lock.lock(); defer { lock.unlock() }
            if let cached = etags[key] { resp = HTTPResponse(status: 200, headers: resp.headers, body: cached.body) }
        }
        try Self.check(resp)
        if useETag, let tag = resp.headers["etag"] { lock.lock(); etags[key] = (tag, resp.body); lock.unlock() }
        return resp
    }

    static func message(_ r: HTTPResponse) -> String {
        let j = JSONValue.parse(String(decoding: r.body, as: UTF8.self))
        var m = j["message"]?.stringValue ?? String(decoding: r.body.prefix(200), as: UTF8.self)
        if let errs = j["errors"]?.arrayValue {
            let detail = errs.compactMap { $0.stringValue ?? $0["message"]?.stringValue ?? $0["code"]?.stringValue }
            if !detail.isEmpty { m += " (" + detail.joined(separator: ", ") + ")" }
        }
        return m
    }

    /// Maps status codes to typed errors. A 403/429 that is really the rate limit becomes a retryable error with its reset time.
    static func check(_ r: HTTPResponse) throws {
        guard r.status >= 300 else { return }
        let msg = message(r)
        switch r.status {
        case 401: throw TrackerError.unauthorized
        case 404: throw TrackerError.notFound(msg)
        case 422: throw TrackerError.validation(msg)
        case 403, 429:
            let remaining = r.headers["x-ratelimit-remaining"]
            if remaining == "0" || r.headers["retry-after"] != nil || r.status == 429 || msg.lowercased().contains("rate limit") {
                var reset: Date?
                if let ra = r.headers["retry-after"], let secs = Double(ra) { reset = Date().addingTimeInterval(secs) }
                else if let rs = r.headers["x-ratelimit-reset"], let t = Double(rs) { reset = Date(timeIntervalSince1970: t) }
                throw TrackerError.rateLimited(resetAt: reset)
            }
            throw TrackerError.http(status: r.status, message: msg)
        default: throw TrackerError.http(status: r.status, message: msg)
        }
    }

    /// Follows `Link: <...>; rel="next"` until the last page.
    func getAll(_ path: String, _ query: [(String, String)] = [], useETag: Bool = false) throws -> [JSONValue] {
        var next: URL? = url(path, query + [("per_page", "100")])
        var out: [JSONValue] = []
        var pages = 0
        while let u = next, pages < 200 {
            let r = try perform("GET", u, useETag: useETag)
            let j = JSONValue.parse(String(decoding: r.body, as: UTF8.self))
            out.append(j)
            next = Self.nextLink(r.headers["link"])
            pages += 1
        }
        return out
    }

    static func nextLink(_ header: String?) -> URL? {
        guard let header else { return nil }
        for part in header.split(separator: ",") {
            let pieces = part.split(separator: ";")
            guard pieces.count >= 2, pieces.dropFirst().contains(where: { $0.contains("rel=\"next\"") }) else { continue }
            let raw = pieces[0].trimmingCharacters(in: .whitespaces)
            guard raw.hasPrefix("<"), raw.hasSuffix(">") else { continue }
            return URL(string: String(raw.dropFirst().dropLast()))
        }
        return nil
    }

    static func issue(_ j: JSONValue) -> RemoteIssue? {
        guard let n = j["number"]?.intValue, let title = j["title"]?.stringValue else { return nil }
        let labels = (j["labels"]?.arrayValue ?? []).compactMap { $0.stringValue ?? $0["name"]?.stringValue }
        return RemoteIssue(number: n, title: title, body: j["body"]?.stringValue ?? "", state: j["state"]?.stringValue ?? "open", labels: labels,
                           updatedAt: GitHubDate.parse(j["updated_at"]?.stringValue) ?? Date(), commentsCount: j["comments"]?.intValue ?? 0,
                           isPullRequest: j["pull_request"] != nil)
    }

    private func repoPath(_ repo: String) -> String { "/repos/\(repo)" }

    // MARK: IssueTracker

    public func createIssue(repo: String, title: String, body: String, labels: [String]) throws -> RemoteIssue {
        let r = try perform("POST", url("\(repoPath(repo))/issues"),
                            body: ["title": .string(title), "body": .string(body), "labels": .array(labels.map { .string($0) })])
        guard let issue = Self.issue(JSONValue.parse(String(decoding: r.body, as: UTF8.self))) else {
            throw TrackerError.http(status: r.status, message: "Unexpected response creating issue")
        }
        return issue
    }

    public func updateIssue(repo: String, number: Int, title: String?, body: String?) throws {
        var payload: [String: JSONValue] = [:]
        if let title { payload["title"] = .string(title) }
        if let body { payload["body"] = .string(body) }
        guard !payload.isEmpty else { return }
        _ = try perform("PATCH", url("\(repoPath(repo))/issues/\(number)"), body: .object(payload))
    }

    public func setLabels(repo: String, number: Int, labels: [String]) throws {
        let current = try perform("GET", url("\(repoPath(repo))/issues/\(number)"))
        let existing = Self.issue(JSONValue.parse(String(decoding: current.body, as: UTF8.self)))?.labels ?? []
        let merged = existing.filter { !isHatchManagedLabel($0) } + labels.filter(isHatchManagedLabel)
        _ = try perform("PUT", url("\(repoPath(repo))/issues/\(number)/labels"), body: ["labels": .array(merged.map { .string($0) })])
    }

    public func addComment(repo: String, number: Int, body: String) throws -> Int {
        let r = try perform("POST", url("\(repoPath(repo))/issues/\(number)/comments"), body: ["body": .string(body)])
        guard let id = JSONValue.parse(String(decoding: r.body, as: UTF8.self))["id"]?.intValue else {
            throw TrackerError.http(status: r.status, message: "Unexpected response adding comment")
        }
        return id
    }

    public func closeIssue(repo: String, number: Int, reason: String) throws {
        _ = try perform("PATCH", url("\(repoPath(repo))/issues/\(number)"), body: ["state": "closed", "state_reason": .string(reason)])
    }

    public func reopenIssue(repo: String, number: Int) throws {
        _ = try perform("PATCH", url("\(repoPath(repo))/issues/\(number)"), body: ["state": "open", "state_reason": "reopened"])
    }

    public func listIssues(repo: String, since: Date?) throws -> [RemoteIssue] {
        var q: [(String, String)] = [("state", "all"), ("sort", "updated"), ("direction", "asc")]
        if let since { q.append(("since", GitHubDate.string(since))) }
        return try getAll("\(repoPath(repo))/issues", q, useETag: true).flatMap { $0.arrayValue ?? [] }.compactMap(Self.issue)
    }

    public func listComments(repo: String, number: Int, since: Date?) throws -> [RemoteComment] {
        var q: [(String, String)] = []
        if let since { q.append(("since", GitHubDate.string(since))) }
        return try getAll("\(repoPath(repo))/issues/\(number)/comments", q).flatMap { $0.arrayValue ?? [] }.compactMap { j in
            guard let id = j["id"]?.intValue else { return nil }
            return RemoteComment(id: id, body: j["body"]?.stringValue ?? "", author: j["user"]?["login"]?.stringValue ?? "unknown",
                                 createdAt: GitHubDate.parse(j["created_at"]?.stringValue) ?? Date())
        }
    }

    public func ensureLabels(repo: String, _ labels: [LabelSpec]) throws {
        let have = Set(try getAll("\(repoPath(repo))/labels").flatMap { $0.arrayValue ?? [] }.compactMap { $0["name"]?.stringValue?.lowercased() })
        for spec in labels where !have.contains(spec.name.lowercased()) {
            do {
                _ = try perform("POST", url("\(repoPath(repo))/labels"),
                                body: ["name": .string(spec.name), "color": .string(spec.color), "description": .string(spec.description)])
            } catch TrackerError.validation { continue }   // created meanwhile: already_exists
        }
    }

    public func putFile(repo: String, path: String, data: Data, message: String, branch: String) throws -> String {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let fileURL = url("\(repoPath(repo))/contents/\(encoded)", [("ref", branch)])
        var sha: String?
        do {
            let r = try perform("GET", fileURL)
            sha = JSONValue.parse(String(decoding: r.body, as: UTF8.self))["sha"]?.stringValue
        } catch TrackerError.notFound { sha = nil }
        var body: [String: JSONValue] = ["message": .string(message), "content": .string(data.base64EncodedString()), "branch": .string(branch)]
        if let sha { body["sha"] = .string(sha) }
        let r = try perform("PUT", url("\(repoPath(repo))/contents/\(encoded)"), body: .object(body))
        return JSONValue.parse(String(decoding: r.body, as: UTF8.self))["content"]?["sha"]?.stringValue ?? ""
    }

    public func checkRuns(repo: String, ref: String) throws -> [CheckRun] {
        let encoded = ref.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ref
        return try getAll("\(repoPath(repo))/commits/\(encoded)/check-runs").flatMap { $0["check_runs"]?.arrayValue ?? [] }.compactMap { j in
            guard let name = j["name"]?.stringValue else { return nil }
            return CheckRun(name: name, status: j["status"]?.stringValue ?? "queued", conclusion: j["conclusion"]?.stringValue)
        }
    }
}
