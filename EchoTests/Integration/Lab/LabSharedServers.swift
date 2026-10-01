import Foundation
import ServerLabClient
import Synchronization
import XCTest

/// One echo-server-lab server per recipe for the whole test run, for the XCTest suites (Swift
/// Testing suites use `.server(...)` instead). The first suite that asks starts it; it is removed
/// when the test bundle finishes. Its owner names this process (`EchoTests@<machine>:<pid>`), so
/// when the process is killed the next one removes it (`serverlab down --abandoned`).
actor LabSharedServers {
    static let shared = LabSharedServers()

    private var starts: [String: Task<LabServer, any Error>] = [:]
    private var observerRegistered = false
    private var abandonedRemoved = false

    func server(for recipe: String) async throws -> LabServer {
        if let start = starts[recipe] { return try await start.value }
        if !abandonedRemoved {
            // A test process killed for a test over its time limit leaves its servers behind; the
            // next process (this one) removes them before starting its own.
            abandonedRemoved = true
            try? await ServerLabCLI.removeAbandoned()
        }
        let start = Task(name: "lab-server-\(recipe)") {
            try await ServerLabCLI.up(recipe, owner: ServerLabCLI.processOwner("EchoTests"), leaseMinutes: 120)
        }
        starts[recipe] = start
        if !observerRegistered {
            observerRegistered = true
            let cli = try await ServerLabCLI.executable()
            await MainActor.run { XCTestObservationCenter.shared.addTestObserver(LabSharedServerRemoval(cli: cli)) }
        }
        do {
            let server = try await start.value
            LabSharedServerRemoval.started(server.containerName)
            print("[serverlab] \(recipe): \(server.containerName) at \(server.host):\(server.port)")
            return server
        } catch {
            // The next suite tries again rather than failing on a start that never happened.
            starts[recipe] = nil
            throw error
        }
    }
}

/// Removes the shared servers when the test bundle finishes. XCTest calls the observer
/// synchronously, so `serverlab down` runs as a child process the observer waits for.
final class LabSharedServerRemoval: NSObject, XCTestObservation {
    private static let startedContainers = Mutex<[String]>([])
    private let cli: URL

    init(cli: URL) {
        self.cli = cli
    }

    static func started(_ containerName: String) {
        startedContainers.withLock { $0.append(containerName) }
    }

    func testBundleDidFinish(_ testBundle: Bundle) {
        let containers = Self.startedContainers.withLock { $0 }
        guard !containers.isEmpty else { return }
        let process = Process()
        process.executableURL = cli
        process.arguments = ["down"] + containers
        try? process.run()
        process.waitUntilExit()
    }
}

extension XCTestCase {
    /// The shared lab server for `recipe`, or a skip when lab suites are switched off. Getting it can
    /// take minutes (the server's start, the lab's memory budget), so the test may run 15 minutes
    /// while it waits and has two minutes from the moment it has the server: a slow start is not a
    /// hang, and a hang still fails fast.
    nonisolated(nonsending) func labServer(_ recipe: String) async throws -> LabServer {
        guard labIntegrationEnabled else { throw XCTSkip("\(labIntegrationNote)") }
        let started = ContinuousClock.now
        executionTimeAllowance = 900
        let server = try await LabSharedServers.shared.server(for: recipe)
        executionTimeAllowance = TimeInterval((ContinuousClock.now - started).components.seconds) + 120
        return server
    }
}
