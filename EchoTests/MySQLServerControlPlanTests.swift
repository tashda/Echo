import Foundation
import Testing
@testable import Echo

@Suite("MySQL Server Control Plan")
struct MySQLServerControlPlanTests {
    @Test("Restart prefers mysql.server when available")
    func restartPrefersMysqlServerScript() throws {
        let tempDirectory = try makeToolDirectory(with: ["mysql.server", "mysqladmin", "mysqld"])
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let plan = try #require(
            MySQLServerControlPlan.restart(
                host: "localhost",
                port: 3306,
                username: "root",
                password: "secret",
                customToolPath: tempDirectory.path,
                defaultsFilePath: "/tmp/my.cnf"
            )
        )

        #expect(plan == .single(
            MySQLServerControlProcessPlan(
                executable: tempDirectory.appendingPathComponent("mysql.server"),
                arguments: ["restart"],
                environment: [:]
            )
        ))
    }

    @Test("Restart falls back to stop then start when mysql.server is unavailable")
    func restartFallsBackToStopThenStart() throws {
        let tempDirectory = try makeToolDirectory(with: ["mysqladmin", "mysqld"])
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let plan = try #require(
            MySQLServerControlPlan.restart(
                host: "127.0.0.1",
                port: 3307,
                username: "echo",
                password: "topsecret",
                customToolPath: tempDirectory.path,
                defaultsFilePath: "/tmp/mysql.cnf"
            )
        )

        #expect(plan == .stopThenStart(
            stop: MySQLServerControlProcessPlan(
                executable: tempDirectory.appendingPathComponent("mysqladmin"),
                arguments: [
                    "--host=127.0.0.1",
                    "--port=3307",
                    "--user=echo",
                    "shutdown",
                ],
                environment: ["MYSQL_PWD": "topsecret"]
            ),
            start: MySQLServerControlProcessPlan(
                executable: tempDirectory.appendingPathComponent("mysqld"),
                arguments: [
                    "--defaults-file=/tmp/mysql.cnf",
                    "--daemonize",
                ],
                environment: [:]
            )
        ))
    }

    @Test("Start uses mysqld with defaults file when mysql.server is unavailable")
    func startUsesMysqldFallback() throws {
        let tempDirectory = try makeToolDirectory(with: ["mysqld"])
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let plan = MySQLServerControlPlan.start(
            customToolPath: tempDirectory.path,
            defaultsFilePath: "/tmp/my.cnf"
        )

        #expect(plan == MySQLServerControlProcessPlan(
            executable: tempDirectory.appendingPathComponent("mysqld"),
            arguments: [
                "--defaults-file=/tmp/my.cnf",
                "--daemonize",
            ],
            environment: [:]
        ))
    }

    private func makeToolDirectory(with tools: [String]) throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echo_mysql_control_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for tool in tools {
            let url = directory.appendingPathComponent(tool)
            try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }

        return directory
    }
}
