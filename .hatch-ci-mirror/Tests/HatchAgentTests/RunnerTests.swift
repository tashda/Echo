import XCTest
@testable import HatchAgent

final class ClaudeCLIRunnerTests: XCTestCase {
    var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("runner-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// Writes an executable shell script that stands in for `claude`.
    func fake(_ body: String) throws -> String {
        let url = dir.appendingPathComponent("claude")
        try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url.path
    }

    var argsFile: String { dir.appendingPathComponent("args.txt").path }

    func testReadsResultAndTokens() throws {
        let exe = try fake(#"""
        printf '%s\n' "$@" > "\#(argsFile)"
        echo '{"type":"result","subtype":"success","is_error":false,"result":"{\"questions\":[]}","usage":{"input_tokens":100,"output_tokens":7,"cache_creation_input_tokens":20,"cache_read_input_tokens":300}}'
        """#)
        let out = try ClaudeCLIRunner(executable: exe, model: "sonnet").run(prompt: "hello there", options: AgentOptions())
        XCTAssertEqual(out.text, #"{"questions":[]}"#)
        XCTAssertEqual(out.tokensIn, 420, "cache reads and writes are input too")
        XCTAssertEqual(out.tokensOut, 7)
        let args = try String(contentsOfFile: argsFile).split(separator: "\n").map(String.init)
        XCTAssertEqual(args, ["-p", "hello there", "--output-format", "json", "--model", "sonnet"])
    }

    func testOptionsOverrideTheRunnersModelAndDirectory() throws {
        let exe = try fake(#"""
        printf '%s\n' "$@" > "\#(argsFile)"
        pwd > "\#(dir.path)/cwd.txt"
        echo '{"result":"ok","usage":{}}'
        """#)
        let work = dir.appendingPathComponent("work")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        _ = try ClaudeCLIRunner(executable: exe, model: "sonnet").run(prompt: "p", options: AgentOptions(model: "haiku", workingDirectory: work))
        XCTAssertTrue(try String(contentsOfFile: argsFile).contains("haiku"))
        let cwd = try String(contentsOfFile: dir.appendingPathComponent("cwd.txt").path).trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(cwd.hasSuffix("/work"), cwd)
    }

    func testMissingExecutableGivesAClearError() {
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: "/nonexistent/claude").run(prompt: "p", options: AgentOptions())) { e in
            XCTAssertEqual(e as? AgentRunnerError, .executableNotFound("/nonexistent/claude"))
            XCTAssertTrue("\(e)".contains("Could not find the agent program"))
        }
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: "no-such-program-hatch").run(prompt: "p", options: AgentOptions()))
    }

    func testNonZeroExitCarriesTheMessage() throws {
        let exe = try fake("echo 'login required' >&2; exit 3")
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: exe).run(prompt: "p", options: AgentOptions())) { e in
            XCTAssertEqual(e as? AgentRunnerError, .failed(code: 3, stderr: "login required"))
        }
    }

    func testErrorResultIsAnError() throws {
        let exe = try fake(#"echo '{"is_error":true,"result":"Credit balance too low","usage":{}}'"#)
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: exe).run(prompt: "p", options: AgentOptions())) { e in
            XCTAssertTrue("\(e)".contains("Credit balance"))
        }
    }

    func testGarbageOutputIsReported() throws {
        let exe = try fake("echo 'Welcome to the program'")
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: exe).run(prompt: "p", options: AgentOptions())) { e in
            guard case AgentRunnerError.badOutput = e else { return XCTFail("\(e)") }
        }
    }

    func testTimeoutStopsTheProgram() throws {
        let exe = try fake("sleep 30")
        let started = Date()
        XCTAssertThrowsError(try ClaudeCLIRunner(executable: exe, timeout: 1).run(prompt: "p", options: AgentOptions())) { e in
            XCTAssertEqual(e as? AgentRunnerError, .timedOut(seconds: 1))
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 10)
    }

    func testHugePromptGoesThroughStdin() throws {
        let exe = try fake(#"""
        printf '%s\n' "$@" > "\#(argsFile)"
        wc -c > "\#(dir.path)/stdin.txt"
        echo '{"result":"big","usage":{"input_tokens":1,"output_tokens":1}}'
        """#)
        let prompt = String(repeating: "x", count: 150_000)
        let out = try ClaudeCLIRunner(executable: exe).run(prompt: prompt, options: AgentOptions())
        XCTAssertEqual(out.text, "big")
        XCTAssertEqual(try String(contentsOfFile: argsFile).split(separator: "\n").first, "-p")
        XCTAssertFalse(try String(contentsOfFile: argsFile).contains("xxxx"))
        XCTAssertEqual(try String(contentsOfFile: dir.appendingPathComponent("stdin.txt").path).trimmingCharacters(in: .whitespacesAndNewlines), "150000")
    }

    func testParsesAnEventArray() throws {
        let out = try ClaudeCLIRunner.parse(#"[{"type":"system"},{"type":"result","result":"done","usage":{"input_tokens":5,"output_tokens":2}}]"#)
        XCTAssertEqual(out, AgentOutput(text: "done", tokensIn: 5, tokensOut: 2))
    }

    func testBareNameIsFoundOnPath() throws {
        XCTAssertNotNil(ClaudeCLIRunner(executable: "sh").resolvedExecutable())
        XCTAssertNil(ClaudeCLIRunner(executable: "no-such-program-hatch").resolvedExecutable())
    }

    func testVettingEndToEndThroughTheFakeProgram() throws {
        let exe = try fake(#"echo '{"result":"{\"questions\":[{\"text\":\"Which toast?\",\"suggestions\":[\"A\"]}]}","usage":{"input_tokens":50,"output_tokens":9}}'"#)
        let (store, p) = try Fixture.store()
        let t = try Fixture.ticket(store, p, type: .bug, title: "Toast broken", body: "x")
        try store.move(t.id, to: .checking, actor: .owner)
        let outcome = try VettingService(store: store, runner: ClaudeCLIRunner(executable: exe)).vet(ticketId: t.id)
        guard case .vetted(let o) = outcome else { return XCTFail("\(outcome)") }
        XCTAssertEqual(o.status, .needsAnswers)
        XCTAssertEqual(try store.tokenTotals(ticketId: t.id).input, 50)
    }
}
