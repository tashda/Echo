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
        for directory in searchDirectories(customPath: customPath) {
            let tool = URL(fileURLWithPath: directory).appendingPathComponent(name)
            if isUsableTool(at: tool) {
                return tool
            }
        }

        // which fallback
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
                let tool = URL(fileURLWithPath: path)
                if !path.isEmpty, isUsableTool(at: tool) {
                    return tool
                }
            }
        } catch {
            // Ignore — fallback exhausted
        }

        return nil
    }

    private static func searchDirectories(customPath: String?) -> [String] {
        var directories: [String] = []

        if let customPath, !customPath.isEmpty {
            directories.append(customPath)
        }

        let env = ProcessInfo.processInfo.environment
        if let envPath = env["ECHO_PG_TOOL_PATH"], !envPath.isEmpty {
            directories.append(envPath)
        }
        if let envPath = env["TEST_PG_TOOL_PATH"], !envPath.isEmpty {
            directories.append(envPath)
        }

        if let sharedSupportURL = Bundle.main.sharedSupportURL {
            directories.append(sharedSupportURL.appendingPathComponent("PostgresTools").path)
        }

        directories.append(contentsOf: preferredSystemSearchDirectories())
        return uniquePreservingOrder(directories)
    }

    private static func preferredSystemSearchDirectories() -> [String] {
        let arch = currentArchitecture()
        let homebrewRoot = arch == "x86_64" ? "/usr/local" : "/opt/homebrew"
        let fallbackRoot = arch == "x86_64" ? "/opt/homebrew" : "/usr/local"

        return [
            "\(homebrewRoot)/opt/libpq/bin",
            "\(homebrewRoot)/bin"
        ] + homebrewVersionedSearchDirectories(root: homebrewRoot) + [
            "/Applications/Postgres.app/Contents/Versions/latest/bin",
            "\(fallbackRoot)/opt/libpq/bin",
            "\(fallbackRoot)/bin"
        ] + homebrewVersionedSearchDirectories(root: fallbackRoot)
    }

    private static func homebrewVersionedSearchDirectories(root: String) -> [String] {
        let versions = ["18", "17", "16", "15", "14"]
        return versions.map { version in
            "\(root)/opt/postgresql@\(version)/bin"
        }
    }

    private static func isUsableTool(at url: URL) -> Bool {
        let path = url.path
        guard FileManager.default.isExecutableFile(atPath: path) else { return false }
        return isCompatibleExecutable(at: path)
    }

    private static func isCompatibleExecutable(at path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = ["-b", path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return true }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let description = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if !description.contains("Mach-O") {
                return true
            }

            let arch = currentArchitecture()
            return description.contains("universal")
                || description.contains(arch)
                || (arch == "x86_64" && description.contains("x86_64h"))
        } catch {
            return true
        }
    }

    private static func currentArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let bytes = withUnsafePointer(to: &systemInfo.machine) {
            UnsafeRawPointer($0).assumingMemoryBound(to: CChar.self)
        }
        return String(cString: bytes)
    }

    private static func uniquePreservingOrder(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for value in values where seen.insert(value).inserted {
            unique.append(value)
        }
        return unique
    }
}
