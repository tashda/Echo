import Foundation
import XCTest
@testable import Echo

/// Echo Labs round 23 (failover) end to end: a saved connection with two servers connects, Test
/// checks both, and when the first stops Echo carries on with the second and reports the move.
/// Needs two servers (postgres-wire's Tests/Fixtures/failover/start-servers.sh):
/// ECHO_E2E_PG_FAILOVER_PORTS="54351,54352" and ECHO_E2E_PG_FAILOVER_CONTAINER_A.
final class PostgresFailoverTests: XCTestCase {
    private var ports: [Int] = []
    private var containerA = ""

    override func setUp() async throws {
        try await super.setUp()
        let env = ProcessInfo.processInfo.environment
        guard let text = env["ECHO_E2E_PG_FAILOVER_PORTS"], let container = env["ECHO_E2E_PG_FAILOVER_CONTAINER_A"] else {
            throw XCTSkip("ECHO_E2E_PG_FAILOVER_PORTS not set")
        }
        ports = text.split(separator: ",").compactMap { Int($0) }
        containerA = container
        docker("start", containerA)
        try await Task.sleep(for: .seconds(2))
    }

    override func tearDown() async throws {
        docker("start", containerA)
        try await super.tearDown()
    }

    @discardableResult
    private func docker(_ arguments: String...) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["docker"] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    private var connection: SavedConnection {
        var connection = SavedConnection(connectionName: "Cluster", host: "127.0.0.1", port: ports[0], database: "postgres",
                                         username: "postgres", tlsMode: .disable)
        connection.additionalHosts = [ConnectionHost(host: "127.0.0.1", port: ports[1])]
        return connection
    }

    private let credentials = DatabaseAuthenticationConfiguration(method: .sqlPassword, username: "postgres", password: "postgres")

    func testTestChecksEveryServer() async {
        let result = await PostgresConnectionTest.testServers(connection, authentication: credentials, connectTimeoutSeconds: 3)
        XCTAssertTrue(result.isSuccessful, result.message)
        XCTAssertEqual(result.serverLines.count, 2)
        XCTAssertTrue(result.message.hasSuffix("connects to 127.0.0.1:\(ports[0])"), result.message)
    }

    func testTheSessionMovesToTheSecondServerAndSaysSo() async throws {
        let session = try await PostgresNIOFactory().connect(to: connection, database: "postgres", authentication: credentials, connectTimeoutSeconds: 3)
        defer { Task { await session.close() } }
        let postgres = try XCTUnwrap(session as? PostgresSession)
        XCTAssertEqual(postgres.client.currentHost.port, ports[0])
        let changes = postgres.client.hostChanges()
        let first = Task { () -> Int? in
            for await change in changes { return change.to.port }
            return nil
        }

        docker("stop", "-t", "0", containerA)
        _ = try await session.simpleQuery("SELECT 1")
        let movedTo = await first.value
        XCTAssertEqual(movedTo, ports[1])
        XCTAssertEqual(postgres.client.currentHost.port, ports[1])
    }
}
