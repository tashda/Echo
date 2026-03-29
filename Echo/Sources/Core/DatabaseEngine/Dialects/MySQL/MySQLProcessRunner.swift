import Foundation

nonisolated final class MySQLProcessRunner: Sendable {
    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        standardInput: Any? = nil,
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let collector = MySQLStderrCollector(onStderr: onStderr)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            env.removeValue(forKey: "MYSQL_PWD")
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env
            process.standardOutput = Pipe()
            process.standardInput = standardInput

            let stderrPipe = Pipe()
            process.standardError = stderrPipe
            stderrPipe.fileHandleForReading.readabilityHandler = { [collector] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                collector.append(text)
            }

            process.terminationHandler = { [collector] proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                    collector.append(text)
                }
                continuation.resume(returning: ProcessResult(exitCode: proc.terminationStatus, stderrLines: collector.lines))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private final class MySQLStderrCollector: Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var storedLines: [String] = []
    private let onStderr: (@Sendable (String) -> Void)?

    init(onStderr: (@Sendable (String) -> Void)?) {
        self.onStderr = onStderr
    }

    func append(_ text: String) {
        let newLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty }
        lock.lock()
        storedLines.append(contentsOf: newLines)
        lock.unlock()
        for line in newLines {
            onStderr?(line)
        }
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storedLines
    }
}
