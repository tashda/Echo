import Foundation
import ServerLabKit

/// Actions on the parts of a server started from the Servers page: restarts, failover, network
/// faults and Microsoft's sqlcmd. Each reports to the page log.
extension LabServersModel {
    func stop(part: String, of server: LabDatabaseServer) async {
        await run("Stopped \(part) of \(server.containerName)") { try await $0.stop(part: part, of: server) }
    }

    func start(part: String, of server: LabDatabaseServer) async {
        await run("Started \(part) of \(server.containerName) again") { lab in
            try await lab.start(part: part, of: server, log: { line in Task { @MainActor in LabServersModel.shared.append(line) } })
        }
    }

    func promote(part: String, of server: LabDatabaseServer) async {
        await run("Promoted \(part) of \(server.containerName)") { try await $0.promote(part: part, of: server) }
    }

    func addFaultProxy(to server: LabDatabaseServer) async {
        guard let lab else { return }
        do {
            let withProxy = try await lab.startFaultProxy(for: server)
            replaceStarted(withProxy)
            append("Fault proxy for \(server.containerName) on port \(withProxy.parts.last?.port ?? 0)")
        } catch {
            append("Fault proxy failed: \(error)")
        }
    }

    func addFault(_ fault: LabFault, to server: LabDatabaseServer) async {
        await run("Added \(fault) to \(server.containerName)") { _ = try await $0.addFault(fault, to: server) }
    }

    func clearFaults(of server: LabDatabaseServer) async {
        await run("Cleared the faults of \(server.containerName)") { try await $0.clearFaults(of: server) }
    }

    func cutConnections(of server: LabDatabaseServer) async {
        await run("Cut the network of \(server.containerName)") { try await $0.cutConnections(of: server) }
    }

    func restoreConnections(of server: LabDatabaseServer) async {
        await run("Restored the network of \(server.containerName)") { try await $0.restoreConnections(of: server) }
    }

    /// Runs SQL through Microsoft's sqlcmd; with a capture on, it shows up readable in Explained.
    func runMicrosoftClient(_ sql: String, on server: LabDatabaseServer) async {
        guard let lab else { return }
        do {
            let output = try await lab.runMicrosoftClient(server, sql: sql)
            append("sqlcmd: \(output.split(separator: "\n").prefix(20).joined(separator: "\n"))")
        } catch {
            append("sqlcmd failed: \(error)")
        }
    }

    private func run(_ done: String, _ action: (ServerLab) async throws -> Void) async {
        guard let lab else { return }
        do {
            try await action(lab)
            append(done)
        } catch {
            append("Failed: \(error)")
        }
        await refresh()
    }
}
