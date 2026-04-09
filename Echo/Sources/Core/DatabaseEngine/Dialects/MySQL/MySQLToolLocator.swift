import Foundation

nonisolated struct MySQLToolLocator {
    static func mysqldumpURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysqldump", customPath: customPath)
    }

    static func mysqlURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysql", customPath: customPath)
    }

    static func mysqlpumpURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysqlpump", customPath: customPath)
    }

    static func mysqladminURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysqladmin", customPath: customPath)
    }

    static func mysqlServerScriptURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysql.server", customPath: customPath)
    }

    static func mysqldSafeURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysqld_safe", customPath: customPath)
    }

    static func mysqldURL(customPath: String? = nil) -> URL? {
        locateTool(name: "mysqld", customPath: customPath)
    }

    private static func locateTool(name: String, customPath: String?) -> URL? {
        // When a custom path is explicitly provided, restrict the search to that
        // directory only. The caller chose a specific tool location — do not fall
        // through to system paths or `which`.
        if let customPath, !customPath.isEmpty {
            let tool = URL(fileURLWithPath: customPath).appendingPathComponent(name)
            return FileManager.default.isExecutableFile(atPath: tool.path) ? tool : nil
        }

        for directory in searchDirectories() {
            let tool = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: tool.path) {
                return tool
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) else { return nil }
            return URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }

    private static func searchDirectories() -> [String] {
        var directories: [String] = []

        let env = ProcessInfo.processInfo.environment
        if let envPath = env["ECHO_MYSQL_TOOL_PATH"], !envPath.isEmpty {
            directories.append(envPath)
        }
        if let envPath = env["TEST_MYSQL_TOOL_PATH"], !envPath.isEmpty {
            directories.append(envPath)
        }

        if let sharedSupportURL = Bundle.main.sharedSupportURL {
            directories.append(sharedSupportURL.appendingPathComponent("MySQLTools").path)
        }

        directories.append(contentsOf: [
            "/opt/homebrew/opt/mysql@8.4/bin",
            "/opt/homebrew/opt/mysql@8.0/bin",
            "/opt/homebrew/opt/mysql/bin",
            "/opt/homebrew/opt/mysql@8.4/support-files",
            "/opt/homebrew/opt/mysql@8.0/support-files",
            "/opt/homebrew/opt/mysql/support-files",
            "/usr/local/opt/mysql@8.4/bin",
            "/usr/local/opt/mysql@8.0/bin",
            "/usr/local/opt/mysql/bin",
            "/usr/local/opt/mysql@8.4/support-files",
            "/usr/local/opt/mysql@8.0/support-files",
            "/usr/local/opt/mysql/support-files",
            "/usr/local/mysql/bin",
            "/usr/local/mysql/support-files",
        ])

        var seen = Set<String>()
        return directories.filter { seen.insert($0).inserted }
    }
}
