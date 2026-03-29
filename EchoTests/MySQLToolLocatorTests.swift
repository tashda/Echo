import Foundation
import Testing
@testable import Echo

@Suite("MySQL Tool Locator")
struct MySQLToolLocatorTests {
    @Test("Environment tool path takes precedence")
    func environmentToolPathTakesPrecedence() throws {
        let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("echo_mysql_tools_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        for tool in ["mysqldump", "mysql", "mysqlpump", "mysqladmin", "mysql.server", "mysqld"] {
            let url = tempDirectory.appendingPathComponent(tool)
            try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }

        let previousPointer = getenv("ECHO_MYSQL_TOOL_PATH")
        let previous = previousPointer.map { String(cString: $0) }
        setenv("ECHO_MYSQL_TOOL_PATH", tempDirectory.path, 1)
        defer {
            if let previous {
                setenv("ECHO_MYSQL_TOOL_PATH", previous, 1)
            } else {
                unsetenv("ECHO_MYSQL_TOOL_PATH")
            }
        }

        #expect(MySQLToolLocator.mysqldumpURL()?.path == tempDirectory.appendingPathComponent("mysqldump").path)
        #expect(MySQLToolLocator.mysqlURL()?.path == tempDirectory.appendingPathComponent("mysql").path)
        #expect(MySQLToolLocator.mysqlpumpURL()?.path == tempDirectory.appendingPathComponent("mysqlpump").path)
        #expect(MySQLToolLocator.mysqladminURL()?.path == tempDirectory.appendingPathComponent("mysqladmin").path)
        #expect(MySQLToolLocator.mysqlServerScriptURL()?.path == tempDirectory.appendingPathComponent("mysql.server").path)
        #expect(MySQLToolLocator.mysqldURL()?.path == tempDirectory.appendingPathComponent("mysqld").path)
    }
}
