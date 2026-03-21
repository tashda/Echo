import Testing
import Foundation
@testable import Echo

@Suite("Postgres Tool Locator")
struct PostgresToolLocatorTests {
    @Test("Environment tool path takes precedence")
    func environmentToolPathTakesPrecedence() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echo_pg_tools_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        for tool in ["pg_dump", "pg_restore", "psql"] {
            let url = tempDirectory.appendingPathComponent(tool)
            try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }

        let previousPointer = getenv("ECHO_PG_TOOL_PATH")
        let previous = previousPointer.map { String(cString: $0) }
        setenv("ECHO_PG_TOOL_PATH", tempDirectory.path, 1)
        defer {
            if let previous {
                setenv("ECHO_PG_TOOL_PATH", previous, 1)
            } else {
                unsetenv("ECHO_PG_TOOL_PATH")
            }
        }

        #expect(PostgresToolLocator.pgDumpURL()?.path == tempDirectory.appendingPathComponent("pg_dump").path)
        #expect(PostgresToolLocator.pgRestoreURL()?.path == tempDirectory.appendingPathComponent("pg_restore").path)
        #expect(PostgresToolLocator.psqlURL()?.path == tempDirectory.appendingPathComponent("psql").path)
    }
}
