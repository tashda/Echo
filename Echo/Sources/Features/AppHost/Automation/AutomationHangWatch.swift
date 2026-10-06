#if DEBUG
import Foundation

/// Catches what a CPU profile misses: a main thread that is stuck waiting (a lock, a synchronous call), not computing.
/// A watcher thread asks the main thread to answer every 100 ms; when it hasn't for 600 ms it runs `/usr/bin/sample`
/// on Echo for a second, so the stuck stack is on disk. `ECHO_HANG_SAMPLES=<directory>` turns it on (with automation).
nonisolated enum AutomationHangWatch {
    private final class Pulse: @unchecked Sendable {
        private let lock = NSLock()
        private var last = Date()
        func touch() { lock.lock(); last = Date(); lock.unlock() }
        var silence: TimeInterval { lock.lock(); defer { lock.unlock() }; return Date().timeIntervalSince(last) }
    }

    static func startIfRequested() {
        guard let directory = ProcessInfo.processInfo.environment["ECHO_HANG_SAMPLES"] else { return }
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let pulse = Pulse()
        let pid = ProcessInfo.processInfo.processIdentifier
        Thread.detachNewThread {
            var sampled = false
            var count = 0
            while true {
                Thread.sleep(forTimeInterval: 0.1)
                Task { @MainActor in pulse.touch() }
                let silence = pulse.silence
                if silence < 0.2 { sampled = false }
                guard silence > 0.6, !sampled else { continue }
                sampled = true
                count += 1
                let file = "\(directory)/hang-\(String(format: "%.3f", Date().timeIntervalSince1970))-\(count).txt"
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
                process.arguments = ["\(pid)", "1", "10", "-file", file]
                try? process.run()
                process.waitUntilExit()
            }
        }
    }
}
#endif
