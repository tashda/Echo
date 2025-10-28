import Foundation

enum TestEnv {
    static func loadDotEnv() {
        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath
        let envPath = (cwd as NSString).appendingPathComponent(".env")
        guard fm.fileExists(atPath: envPath) else { return }
        if let content = try? String(contentsOfFile: envPath, encoding: .utf8) {
            for line in content.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                if let eq = trimmed.firstIndex(of: "=") {
                    let key = String(trimmed[..<eq])
                    let value = String(trimmed[trimmed.index(after: eq)...])
                    setenv(key, value, 1)
                }
            }
        }
    }

    static var host: String { ProcessInfo.processInfo.environment["POSTGRES_HOST"] ?? "127.0.0.1" }
    static var port: Int { Int(ProcessInfo.processInfo.environment["POSTGRES_PORT"] ?? "5432") ?? 5432 }
    static var username: String { ProcessInfo.processInfo.environment["POSTGRES_USERNAME"] ?? "postgres" }
    static var password: String? { ProcessInfo.processInfo.environment["POSTGRES_PASSWORD"] }
    static var database: String { ProcessInfo.processInfo.environment["POSTGRES_DATABASE"] ?? "postgres" }
    static var useTLS: Bool { (ProcessInfo.processInfo.environment["POSTGRES_TLS"] ?? "false").lowercased() == "true" }
}

