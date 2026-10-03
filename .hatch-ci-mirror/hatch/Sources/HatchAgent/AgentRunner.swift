import Foundation

public struct AgentOptions: Equatable, Sendable {
    public var model: String?
    public var workingDirectory: URL?
    /// Seconds before the run is stopped. Nil means the runner's own default.
    public var timeout: TimeInterval?
    public init(model: String? = nil, workingDirectory: URL? = nil, timeout: TimeInterval? = nil) {
        self.model = model; self.workingDirectory = workingDirectory; self.timeout = timeout
    }
}

public struct AgentOutput: Equatable, Sendable {
    public var text: String
    public var tokensIn: Int
    public var tokensOut: Int
    public init(text: String, tokensIn: Int = 0, tokensOut: Int = 0) { self.text = text; self.tokensIn = tokensIn; self.tokensOut = tokensOut }
}

public enum AgentRunnerError: Error, CustomStringConvertible, Equatable {
    case executableNotFound(String)
    case failed(code: Int32, stderr: String)
    case timedOut(seconds: Double)
    case badOutput(String)
    case scriptExhausted

    public var description: String {
        switch self {
        case .executableNotFound(let p): return "Could not find the agent program '\(p)'. Install Claude Code or set its path in Settings."
        case .failed(let code, let err): return "The agent program stopped with exit code \(code): \(err.isEmpty ? "no message" : err)"
        case .timedOut(let s): return "The agent did not answer within \(Int(s)) seconds and was stopped."
        case .badOutput(let m): return "The agent program answered in a form Hatch could not read: \(m)"
        case .scriptExhausted: return "The scripted runner has no more replies."
        }
    }
}

/// The only place a model is called. Everything around it is deterministic Swift, so tests swap this for `ScriptedRunner`.
public protocol AgentRunner: Sendable {
    func run(prompt: String, options: AgentOptions) throws -> AgentOutput
}

/// Runs `claude -p <prompt> --output-format json` and reads the answer and the token counts from its JSON.
public struct ClaudeCLIRunner: AgentRunner {
    public var executable: String
    public var model: String?
    public var workingDirectory: URL?
    public var timeout: TimeInterval
    public var extraArguments: [String]

    public init(executable: String = "claude", model: String? = nil, workingDirectory: URL? = nil, timeout: TimeInterval = 300, extraArguments: [String] = []) {
        self.executable = executable; self.model = model; self.workingDirectory = workingDirectory
        self.timeout = timeout; self.extraArguments = extraArguments
    }

    /// Absolute path of the program, searching PATH for a bare name. Nil when it is not there.
    public func resolvedExecutable() -> String? {
        let fm = FileManager.default
        if executable.contains("/") { return fm.isExecutableFile(atPath: executable) ? executable : nil }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/local/bin"
        for dir in path.split(separator: ":") {
            let candidate = "\(dir)/\(executable)"
            if fm.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    /// Prompts larger than this go to stdin, because one argument is limited to about 128 KB on Linux.
    static let maxArgumentBytes = 100_000

    public func run(prompt: String, options: AgentOptions) throws -> AgentOutput {
        guard let program = resolvedExecutable() else { throw AgentRunnerError.executableNotFound(executable) }
        let useStdin = prompt.utf8.count > Self.maxArgumentBytes
        var args = useStdin ? ["-p"] : ["-p", prompt]
        args += ["--output-format", "json"]
        if let m = options.model ?? model { args += ["--model", m] }
        args += extraArguments
        let seconds = options.timeout ?? timeout
        let result = try Self.spawn(program, args, stdin: useStdin ? prompt : nil, directory: options.workingDirectory ?? workingDirectory, timeout: seconds)
        guard result.status == 0 else {
            // The CLI reports some errors as JSON on stdout; prefer that text when it is there.
            let detail = (try? Self.parse(result.stdout))?.text ?? result.stderr
            throw AgentRunnerError.failed(code: result.status, stderr: detail.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return try Self.parse(result.stdout)
    }

    /// Reads the CLI's JSON: `{"result": "...", "usage": {...}}`, or an array of events that ends with such an object.
    /// Input tokens include cache reads and writes, since those are billed input too.
    public static func parse(_ stdout: String) throws -> AgentOutput {
        guard let data = stdout.data(using: .utf8), let any = try? JSONSerialization.jsonObject(with: data) else {
            throw AgentRunnerError.badOutput("not JSON: \(String(stdout.prefix(200)))")
        }
        var object: [String: Any]?
        if let o = any as? [String: Any] { object = o }
        else if let a = any as? [[String: Any]] { object = a.last { ($0["type"] as? String) == "result" } }
        guard let obj = object else { throw AgentRunnerError.badOutput("no result object") }
        guard let text = obj["result"] as? String else { throw AgentRunnerError.badOutput("no \"result\" text") }
        if (obj["is_error"] as? Bool) == true { throw AgentRunnerError.failed(code: 1, stderr: text) }
        let usage = obj["usage"] as? [String: Any] ?? [:]
        func n(_ k: String) -> Int { (usage[k] as? NSNumber)?.intValue ?? 0 }
        return AgentOutput(text: text, tokensIn: n("input_tokens") + n("cache_creation_input_tokens") + n("cache_read_input_tokens"), tokensOut: n("output_tokens"))
    }

    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()
        func append(_ d: Data) { lock.lock(); data.append(d); lock.unlock() }
        var string: String { lock.lock(); defer { lock.unlock() }; return String(decoding: data, as: UTF8.self) }
    }

    static func spawn(_ program: String, _ args: [String], stdin: String?, directory: URL?, timeout: TimeInterval) throws -> (status: Int32, stdout: String, stderr: String) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: program)
        p.arguments = args
        if let directory { p.currentDirectoryURL = directory }
        let out = Pipe(), err = Pipe(), inp = Pipe()
        p.standardOutput = out; p.standardError = err
        p.standardInput = stdin == nil ? FileHandle.nullDevice : inp
        let outC = Collector(), errC = Collector()
        let group = DispatchGroup()
        for (pipe, collector) in [(out, outC), (err, errC)] {
            group.enter()
            DispatchQueue.global().async {
                // Reading to the end in a thread keeps a chatty child from filling the pipe and blocking.
                collector.append(pipe.fileHandleForReading.readDataToEndOfFile())
                group.leave()
            }
        }
        let finished = DispatchSemaphore(value: 0)
        p.terminationHandler = { _ in finished.signal() }
        do { try p.run() } catch { throw AgentRunnerError.executableNotFound(program) }
        if let stdin {
            DispatchQueue.global().async {
                try? inp.fileHandleForWriting.write(contentsOf: Data(stdin.utf8))
                try? inp.fileHandleForWriting.close()
            }
        }
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            p.terminate()
            _ = finished.wait(timeout: .now() + 2)
            if p.isRunning { kill(p.processIdentifier, SIGKILL) }
            throw AgentRunnerError.timedOut(seconds: timeout)
        }
        group.wait()
        return (p.terminationStatus, outC.string, errC.string)
    }
}

/// A runner for tests: replies in order, or from a closure. It records every prompt it was given.
public final class ScriptedRunner: AgentRunner, @unchecked Sendable {
    public typealias Reply = Result<AgentOutput, Error>
    private let lock = NSLock()
    private var replies: [Reply]
    private let handler: (@Sendable (String, AgentOptions) throws -> AgentOutput)?
    private var seenPrompts: [String] = []
    private var seenOptions: [AgentOptions] = []

    public init(replies: [Reply]) { self.replies = replies; self.handler = nil }
    public init(handler: @escaping @Sendable (String, AgentOptions) throws -> AgentOutput) { self.replies = []; self.handler = handler }

    /// One text reply with token counts.
    public convenience init(text: String, tokensIn: Int = 0, tokensOut: Int = 0) {
        self.init(replies: [.success(AgentOutput(text: text, tokensIn: tokensIn, tokensOut: tokensOut))])
    }

    public var prompts: [String] { lock.lock(); defer { lock.unlock() }; return seenPrompts }
    public var optionsSeen: [AgentOptions] { lock.lock(); defer { lock.unlock() }; return seenOptions }

    public func run(prompt: String, options: AgentOptions) throws -> AgentOutput {
        lock.lock()
        seenPrompts.append(prompt); seenOptions.append(options)
        let reply: Reply? = handler == nil ? (replies.isEmpty ? nil : replies.removeFirst()) : nil
        lock.unlock()
        if let handler { return try handler(prompt, options) }
        guard let reply else { throw AgentRunnerError.scriptExhausted }
        return try reply.get()
    }
}
