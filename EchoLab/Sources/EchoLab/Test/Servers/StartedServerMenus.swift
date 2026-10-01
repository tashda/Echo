import EchoDesignSystem
import ServerLabKit
import ServerLabWorkloads
import SwiftUI

/// Parts, fault and workload menus for a server started from the Servers page.
struct StartedServerMenus: View {
    let model: LabServersModel
    let server: LabDatabaseServer

    private var partRoles: [String] { server.parts.map(\.role).filter { $0 != "proxy" } }
    private var hasProxy: Bool { server.parts.contains { $0.role == "proxy" } }

    var body: some View {
        Menu("Parts") {
            ForEach(partRoles, id: \.self) { role in
                Section(role) {
                    Button("Stop \(role)") { Task { await model.stop(part: role, of: server) } }
                    Button("Start \(role) again") { Task { await model.start(part: role, of: server) } }
                    if role != server.mainRole {
                        Button("Promote \(role)") { Task { await model.promote(part: role, of: server) } }
                    }
                }
            }
        }
        .fixedSize()
        .help("Stop and start a part on the same port, or promote a standby or secondary")

        Menu("Faults") {
            if hasProxy {
                Section("Delay") {
                    ForEach([100, 500, 2000], id: \.self) { milliseconds in
                        Button("Latency \(milliseconds) ms") { Task { await model.addFault(.latency(milliseconds: milliseconds), to: server) } }
                    }
                    Button("Bandwidth 64 KB/s") { Task { await model.addFault(.bandwidth(kilobytesPerSecond: 64), to: server) } }
                }
                Section("Break") {
                    Button("Hang (stop all data)") { Task { await model.addFault(.timeout(milliseconds: 0), to: server) } }
                    Button("Reset connections") { Task { await model.addFault(.resetPeer(afterMilliseconds: 0), to: server) } }
                    Button("Cut the network") { Task { await model.cutConnections(of: server) } }
                }
                Section {
                    Button("Restore the network") { Task { await model.restoreConnections(of: server) } }
                    Button("Clear all faults") { Task { await model.clearFaults(of: server) } }
                }
            } else {
                Button("Add a fault proxy") { Task { await model.addFaultProxy(to: server) } }
            }
        }
        .fixedSize()
        .help(hasProxy ? "Faults act on connections to the proxy part's port" : "Faults need a proxy in front of the server")

        Menu("Workload") {
            Button("Blocking chain") { Task { await model.startWorkload(.blockingChain, on: server) } }
            Button("Idle in transaction") { Task { await model.startWorkload(.idleInTransaction, on: server) } }
            Button("Stop workload") { Task { await model.stopWorkload(on: server) } }
                .disabled(model.workloads[server.containerName] == nil)
        }
        .fixedSize()
        .help("Sessions that hold a lock with others waiting, or an open transaction, for the Activity Monitor")
    }
}

/// What a client needs beyond host and port: other parts, TLS and Kerberos.
struct StartedServerDetails: View {
    let server: LabDatabaseServer

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.xxs) {
            ForEach(server.parts.dropFirst(), id: \.containerID) { part in
                Text("\(part.role)  \(server.host):\(part.port)").textSelection(.enabled)
            }
            if let tls = server.tls {
                Text("TLS \(tls.mode.rawValue), \(tls.certificate.rawValue) certificate, CA \(tls.caPath)").textSelection(.enabled)
            }
            if let kerberos = server.kerberos {
                Text("Kerberos \(kerberos.userPrincipal) at \(kerberos.serviceHost):\(server.port), KRB5_CONFIG \(kerberos.configurationPath)")
                    .textSelection(.enabled)
            }
        }
        .font(TypographyTokens.detail)
        .foregroundStyle(ColorTokens.Text.secondary)
    }
}
