import Foundation

/// Where Hatch keeps its files. One place, so the app, the CLI and the Stage agree on the database, token, port and outbox.
public struct HatchPaths: Sendable {
    /// Hatch's support directory (database, `stage-token`, `stage-port`).
    public let home: URL
    /// The Stage's own directory (outbox). Separate so a sandboxed Stage can own it.
    public let stageHome: URL

    public init(home: URL, stageHome: URL? = nil) {
        self.home = home
        self.stageHome = stageHome ?? home.appendingPathComponent("stage", isDirectory: true)
    }

    /// `HATCH_HOME` overrides; otherwise ~/Library/Application Support/Hatch on macOS and ~/.local/share/hatch elsewhere.
    /// `HATCH_STAGE_HOME` overrides the Stage directory.
    public static func current(environment: [String: String] = ProcessInfo.processInfo.environment) -> HatchPaths {
        let home: URL
        if let override = environment["HATCH_HOME"], !override.isEmpty {
            home = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let user = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            #if os(macOS)
            home = user.appendingPathComponent("Library/Application Support/Hatch", isDirectory: true)
            #else
            home = user.appendingPathComponent(".local/share/hatch", isDirectory: true)
            #endif
        }
        let stage = environment["HATCH_STAGE_HOME"].flatMap { $0.isEmpty ? nil : URL(fileURLWithPath: $0, isDirectory: true) }
        return HatchPaths(home: home, stageHome: stage)
    }

    public var databaseURL: URL { home.appendingPathComponent("hatch.sqlite") }
    public var databasePath: String { databaseURL.path }
    public var tokenFile: URL { home.appendingPathComponent("stage-token") }
    public var portFile: URL { home.appendingPathComponent("stage-port") }
    public var outboxFile: URL { stageHome.appendingPathComponent("outbox.jsonl") }
    /// Requests Hatch refused for good (for example the ticket was deleted). Kept so nothing vanishes silently.
    public var rejectedFile: URL { stageHome.appendingPathComponent("outbox-rejected.jsonl") }

    public func createDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try fm.createDirectory(at: stageHome, withIntermediateDirectories: true)
    }
}
