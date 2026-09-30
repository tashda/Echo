import Foundation
import ServerLabClient
import Testing
@testable import Echo

/// Echo Labs round 23 (failover) end to end on two fresh echo-server-lab servers: a saved
/// connection with both connects, Test checks both, and when the first server goes away Echo carries
/// on with the second and reports the move. Both servers are removed afterwards. Run with
/// SERVERLAB_INTEGRATION=1 (TEST_RUNNER_SERVERLAB_INTEGRATION=1 through xcodebuild).
private let labIntegrationEnabled = ProcessInfo.processInfo.environment["SERVERLAB_INTEGRATION"] == "1"

@Suite(.enabled(if: labIntegrationEnabled), .serialized)
struct PostgresFailoverTests {
    /// Starts two servers, runs `body`, and removes whatever is left of them.
    private func withTwoServers(_ body: ([LabServer]) async throws -> Void) async throws {
        var servers: [LabServer] = []
        do {
            servers.append(try await ServerLabCLI.up("pg-17-empty", owner: "echo-tests-failover", leaseMinutes: 30))
            servers.append(try await ServerLabCLI.up("pg-17-empty", owner: "echo-tests-failover", leaseMinutes: 30))
            try await body(servers)
        } catch {
            for server in servers { try? await ServerLabCLI.down(server) }
            throw error
        }
        for server in servers { try? await ServerLabCLI.down(server) }
    }

    private func connection(_ servers: [LabServer]) -> SavedConnection {
        var connection = SavedConnection(connectionName: "Cluster", host: servers[0].host, port: servers[0].port, database: "postgres",
                                         username: servers[0].username, tlsMode: .disable)
        connection.additionalHosts = [ConnectionHost(host: servers[1].host, port: servers[1].port)]
        return connection
    }

    private func credentials(_ server: LabServer) -> DatabaseAuthenticationConfiguration {
        DatabaseAuthenticationConfiguration(method: .sqlPassword, username: server.username, password: server.password)
    }

    @Test func testChecksEveryServerAndTheSessionMovesWhenTheFirstGoesAway() async throws {
        try await withTwoServers { servers in
            let result = await PostgresConnectionTest.testServers(connection(servers), authentication: credentials(servers[0]), connectTimeoutSeconds: 10)
            #expect(result.isSuccessful, "\(result.message)")
            #expect(result.serverLines.count == 2)
            #expect(result.message.hasSuffix("connects to \(servers[0].host):\(servers[0].port)"), "\(result.message)")

            let session = try await PostgresNIOFactory().connect(
                to: connection(servers), database: "postgres", authentication: credentials(servers[0]), connectTimeoutSeconds: 5)
            let postgres = try #require(session as? PostgresSession)
            #expect(postgres.client.currentHost.port == servers[0].port)
            let changes = postgres.client.hostChanges()
            let first = Task { () -> Int? in
                for await change in changes { return change.to.port }
                return nil
            }

            try await ServerLabCLI.down(servers[0])   // the first server goes away
            _ = try await session.simpleQuery("SELECT 1")
            #expect(await first.value == servers[1].port)
            #expect(postgres.client.currentHost.port == servers[1].port)
            await session.close()
        }
    }
}
