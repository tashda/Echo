import Foundation

struct ProcessResult: Sendable {
    let exitCode: Int32
    let stderrLines: [String]
}

nonisolated final class PostgresProcessRunner: Sendable {

    func run(
        executable: URL,
        arguments: [String],
        environment: [String: String] = [:],
        onStderr: (@Sendable (String) -> Void)? = nil
    ) async throws -> ProcessResult {
        let collector = StderrCollector(onStderr: onStderr)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            var env = ProcessInfo.processInfo.environment
            // Remove any inherited PG variables that could interfere
            for key in env.keys where key.hasPrefix("PG") {
                env.removeValue(forKey: key)
            }
            for (key, value) in environment {
                env[key] = value
            }
            process.environment = env

            let stderrPipe = Pipe()
            process.standardOutput = Pipe()
            process.standardError = stderrPipe

            stderrPipe.fileHandleForReading.readabilityHandler = { [collector] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                if let text = String(data: data, encoding: .utf8) {
                    collector.append(text)
                }
            }

            process.terminationHandler = { [collector] proc in
                stderrPipe.fileHandleForReading.readabilityHandler = nil
                let remaining = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                if !remaining.isEmpty, let text = String(data: remaining, encoding: .utf8) {
                    collector.append(text)
                }
                continuation.resume(returning: ProcessResult(
                    exitCode: proc.terminationStatus,
                    stderrLines: collector.lines
                ))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

// MARK: - Stderr Collector

private final class StderrCollector: Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var _lines: [String] = []
    private let onStderr: (@Sendable (String) -> Void)?

    init(onStderr: (@Sendable (String) -> Void)?) {
        self.onStderr = onStderr
    }

    func append(_ text: String) {
        let newLines = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
            .filter { !$0.isEmpty }
        lock.lock()
        _lines.append(contentsOf: newLines)
        lock.unlock()
        for line in newLines {
            onStderr?(line)
        }
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _lines
    }
}
