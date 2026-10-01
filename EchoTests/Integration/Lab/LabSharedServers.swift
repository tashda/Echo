import Foundation
import ServerLabClient
import Synchronization
import XCTest

/// One echo-server-lab server per recipe for the whole test run, for the XCTest suites (Swift
/// Testing suites use `.server(...)` instead). The first suite that asks starts it; it is removed
/// when the test bundle finishes, or by its lease (and CI's owner-prefix cleanup) after a crash.
actor LabSharedServers {
    static let shared = LabSharedServers()

    private var starts: [String: Task<LabServer, any Error>] = [:]
    private var observerRegistered = false

    /// The shared server for an XCTest suite, or a skip when lab suites are switched off.
    static func serverForSuite(_ recipe: String) async throws -> LabServer {
        guard labIntegrationEnabled else { throw XCTSkip("\(labIntegrationNote)") }
        return try await shared.server(for: recipe)
    }

    func server(for recipe: String) async throws -> LabServer {
        if let start = starts[recipe] { return try await start.value }
        let start = Task(name: "lab-server-\(recipe)") {
            try await ServerLabCLI.up(recipe, owner: ServerLabCLI.owner(forSuite: "EchoTests"), leaseMinutes: 120)
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
