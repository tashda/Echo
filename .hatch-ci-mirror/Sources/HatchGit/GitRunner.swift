import Foundation

public struct GitResult: Equatable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String
    public var ok: Bool { exitCode == 0 }
}

public enum GitError: Error, CustomStringConvertible, Equatable {
    case failed(args: [String], exitCode: Int32, stderr: String)
    case invalid(String)
    case ciRequired(String)

    public var description: String {
        switch self {
        case .failed(let args, let code, let err): return "git \(args.joined(separator: " ")) failed (\(code)): \(err)"
        case .invalid(let m): return m
        case .ciRequired(let m): return m
        }
    }
}

/// Runs the real `git` command line. A protocol so the app and tests control the environment (and so a recording fake is possible).
public protocol GitRunner: Sendable {
    func run(_ args: [String], in directory: String?) throws -> GitResult
}

/// Default runner: Foundation.Process. `environment` overrides are layered over the current environment
/// (tests set author/committer identity and ignore the user's global git config this way).
public struct ProcessGit: GitRunner {
    public var environment: [String: String]

    public init(environment: [String: String] = [:]) { self.environment = environment }

    public func run(_ args: [String], in directory: String?) throws -> GitResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        p.arguments = ["git"] + args
        if let directory { p.currentDirectoryURL = URL(fileURLWithPath: directory) }
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        for (k, v) in environment { env[k] = v }
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out; p.standardError = err; p.standardInput = FileHandle.nullDevice
        try p.run()
        // Drain stderr on another thread so a chatty command cannot fill the pipe and deadlock.
        let box = DataBox(), group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async { box.data = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        group.wait()
        p.waitUntilExit()
        return GitResult(exitCode: p.terminationStatus, stdout: String(decoding: outData, as: UTF8.self), stderr: String(decoding: box.data, as: UTF8.self))
    }

    private final class DataBox: @unchecked Sendable { var data = Data() }
}

public extension GitRunner {
    /// Runs git and returns trimmed stdout; throws `GitError.failed` on a non-zero exit.
    @discardableResult
    func git(_ args: [String], in dir: String?) throws -> String {
        let r = try run(args, in: dir)
        guard r.ok else { throw GitError.failed(args: args, exitCode: r.exitCode, stderr: r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return r.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Like `git` but a failure is a normal answer (false / nil), for probes such as "does this branch exist".
    func succeeds(_ args: [String], in dir: String?) -> Bool {
        ((try? run(args, in: dir))?.ok) ?? false
    }

    func lines(_ args: [String], in dir: String?) throws -> [String] {
        try git(args, in: dir).split(whereSeparator: \.isNewline).map(String.init)
    }

    func branchExists(_ branch: String, in dir: String) -> Bool {
        succeeds(["rev-parse", "--verify", "--quiet", "refs/heads/\(branch)"], in: dir)
    }

    func remotes(in dir: String) -> [String] { (try? lines(["remote"], in: dir)) ?? [] }

    /// Files with unresolved merge conflicts in the working tree at `dir`.
    func conflictedFiles(in dir: String) -> [String] {
        ((try? lines(["diff", "--name-only", "--diff-filter=U"], in: dir)) ?? []).sorted()
    }

    /// Best starting point for new work from `branch`: fetches when a remote exists (offline is fine, the failure is ignored)
    /// and returns `<remote>/<branch>` when it is ahead of the local branch, otherwise the local branch.
    func tip(of branch: String, repo: String, fetch: Bool = true) -> String {
        let remote = remotes(in: repo).first
        if fetch, let remote { _ = try? run(["fetch", "--quiet", remote], in: repo) }
        if let remote {
            let remoteRef = "refs/remotes/\(remote)/\(branch)"
            if succeeds(["rev-parse", "--verify", "--quiet", remoteRef], in: repo) {
                if !branchExists(branch, in: repo) || succeeds(["merge-base", "--is-ancestor", "refs/heads/\(branch)", remoteRef], in: repo) { return remoteRef }
            }
        }
        return branch
    }

    func resolve(_ ref: String, in dir: String) throws -> String { try git(["rev-parse", "--verify", ref + "^{commit}"], in: dir) }
}
