import Foundation
import ServerLabKit
import ServerLabWorkloads

/// Live activity on a started server, to look at in Echo's Activity Monitor.
extension LabServersModel {
    func startWorkload(_ kind: LabWorkloadKind, on server: LabDatabaseServer) async {
        await stopWorkload(on: server)
        do {
            workloads[server.containerName] = try await server.startWorkload(kind, waiters: 2)
            append("Started \(kind.rawValue) on \(server.containerName): sessions named \(WorkloadName.application)")
        } catch {
            append("Workload failed: \(error)")
        }
    }

    func stopWorkload(on server: LabDatabaseServer) async {
        guard let workload = workloads.removeValue(forKey: server.containerName) else { return }
        await workload.stop()
        append("Stopped \(workload.kind.rawValue) on \(server.containerName)")
    }
}

private enum WorkloadName {
    static let application = "serverlab-workload"
}
