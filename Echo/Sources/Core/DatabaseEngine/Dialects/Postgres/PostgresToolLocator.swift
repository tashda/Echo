import Foundation

nonisolated struct PostgresToolLocator {

    static func pgDumpURL(customPath: String? = nil) -> URL? {
        locateTool(name: "pg_dump", customPath: customPath)
    }

    static func pgRestoreURL(customPath: String? = nil) -> URL? {
        locateTool(name: "pg_restore", customPath: customPath)
    }

    static func psqlURL(customPath: String? = nil) -> URL? {
        locateTool(name: "psql", customPath: customPath)
    }

    static func version(of tool: URL) async throws -> String {
        let process = Process()
        process.executableURL = tool
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    // MARK: - Private

    private static func locateTool(name: String, customPath: String?) -> URL? {
        // 1. User custom path
        if let custom = customPath, !custom.isEmpty {
            let dir = URL(fileURLWithPath: custom)
            let tool = dir.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: tool.path) {
                return tool
            }
        }

        // 2. App bundle SharedSupport/PostgresTools/
        if let sharedSupportURL = Bundle.main.sharedSupportURL {
            let bundled = sharedSupportURL.appendingPathComponent("PostgresTools").appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        // 3. Common install paths
        let searchPaths = homebrewVersionedSearchPaths(for: name) + [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/Applications/Postgres.app/Contents/Versions/latest/bin/\(name)"
        ]
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }

        // 4. which fallback
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = [name]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = Pipe()
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !path.isEmpty, FileManager.default.isExecutableFile(atPath: path) {
                    return URL(fileURLWithPath: path)
                }
            }
        } catch {
            // Ignore — fallback exhausted
        }

        return nil
    }

    private static func homebrewVersionedSearchPaths(for name: String) -> [String] {
        let versions = ["18", "17", "16", "15", "14"]
        return versions.flatMap { version in
            [
                "/opt/homebrew/opt/postgresql@\(version)/bin/\(name)",
                "/usr/local/opt/postgresql@\(version)/bin/\(name)"
            ]
        }
    }
}
