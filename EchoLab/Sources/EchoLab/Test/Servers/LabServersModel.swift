import Foundation
import Observation
import ServerLabCatalog
import ServerLabKit

/// A server started from a lab recipe (`ServerLabKit.LabServer`; Echo Labs has its own `LabServer`).
typealias LabDatabaseServer = ServerLabKit.LabServer

/// State of the Servers test page: recipes, what runs on the lab host, seeded images and the budget.
/// Talks to the lab only through `ServerLab` (echo-server-lab), the same API tests use.
@MainActor @Observable
final class LabServersModel {
    static let shared = LabServersModel()

    private(set) var lab: ServerLab?
    private(set) var loadError: String?
    private(set) var running: [RunningServer] = []
    private(set) var images: [SeededImage] = []
    private(set) var reservedMB = 0
    private(set) var lastRefresh: Date?
    /// Servers started from this page; only these can be stopped here.
    private(set) var started: [LabDatabaseServer] = []
    private(set) var busyRecipes: Set<String> = []
    private(set) var log: [String] = []
    /// Servers started here with traffic recording on.
    private(set) var capturing: Set<String> = []
    private(set) var wire: [WireMessage] = []
    private(set) var wireServer: String?

    /// Echo Labs marks the servers it starts with this owner.
    static let owner = "echo-labs"

    private init() {
        do {
            lab = try ServerLab.standard()
        } catch {
            loadError = String(describing: error)
        }
    }

    var recipes: [Recipe] { lab?.recipes.recipes ?? [] }
    var budgetMB: Int { lab?.host.memoryBudgetMB ?? 0 }
    var hostName: String { lab?.host.name ?? "" }

    func hasImage(_ recipe: Recipe) -> Bool {
        images.contains { $0.recipe == recipe.name }
    }

    func startedServer(named containerName: String) -> LabDatabaseServer? {
        started.first { $0.containerName == containerName }
    }

    func refresh() async {
        guard let lab else { return }
        do {
            async let servers = lab.running()
            async let seeded = lab.seededImages()
            async let reserved = lab.reservedMemoryMB()
            running = try await servers.sorted { $0.name < $1.name }
            images = try await seeded
            reservedMB = try await reserved
            // `docker ps` shows short IDs; the lab keeps full ones.
            started.removeAll { server in !running.contains { server.containerID.hasPrefix($0.id) } }
            lastRefresh = Date()
        } catch {
            append("Refresh failed: \(error)")
        }
    }

    func build(_ recipe: Recipe) async {
        guard let lab, !busyRecipes.contains(recipe.name) else { return }
        busyRecipes.insert(recipe.name)
        defer { busyRecipes.remove(recipe.name) }
        append("Building \(recipe.name)")
        do {
            let tag = try await lab.seededImage(for: recipe, log: { line in Task { @MainActor in LabServersModel.shared.append(line) } })
            append("Ready: \(tag)")
        } catch {
            append("Build failed: \(error)")
        }
        await refresh()
    }

    func start(_ recipe: Recipe, leaseMinutes: Int, capture: Bool) async {
        guard let lab, !busyRecipes.contains(recipe.name) else { return }
        busyRecipes.insert(recipe.name)
        defer { busyRecipes.remove(recipe.name) }
        append("Starting \(recipe.name) for \(leaseMinutes) minutes")
        do {
            let server = try await lab.start(recipe, owner: Self.owner, lease: .seconds(leaseMinutes * 60),
                                             log: { line in Task { @MainActor in LabServersModel.shared.append(line) } })
            started.append(server)
            if capture {
                try await lab.startCapture(of: server)
                capturing.insert(server.containerName)
            }
            append("Started \(server.containerName) on \(server.host):\(server.port)\(capture ? ", recording traffic" : "")")
        } catch {
            append("Start failed: \(error)")
        }
        await refresh()
    }

    func stop(_ server: LabDatabaseServer) async {
        guard let lab else { return }
        do {
            try await lab.stop(server)
            started.removeAll { $0.containerID == server.containerID }
            append("Stopped \(server.containerName)")
        } catch {
            append("Stop failed: \(error)")
        }
        await refresh()
    }

    func clearLog() { log.removeAll() }

    /// Decodes the traffic recorded for a server started here.
    func refreshWire(for containerName: String) async {
        guard let lab, let server = startedServer(named: containerName), capturing.contains(containerName) else { return }
        do {
            wire = try await lab.wireMessages(of: server)
            wireServer = containerName
        } catch {
            append("Decoding the capture failed: \(error)")
        }
    }

    /// Saves the capture next to the lab's other files and opens it in Wireshark.
    func openInWireshark(_ containerName: String) async {
        guard let lab, let server = startedServer(named: containerName) else { return }
        do {
            let folder = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".echo-testlab/captures")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "\(containerName).pcap")
            try await lab.captureData(of: server).write(to: file)
            LabWireshark.open(file)
        } catch {
            append("Could not open the capture: \(error)")
        }
    }

    func append(_ line: String) {
        log.append(line)
        if log.count > 500 { log.removeFirst(log.count - 500) }
    }
}
