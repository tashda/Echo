#if DEBUG
import Foundation

/// A list of steps an unattended Echo performs by itself, so animations can be recorded and
/// traced without synthetic clicks. Loaded from the file `ECHO_AUTOMATION_SCRIPT` names:
///
///     {
///       "connect": ["Test Postgres", "Test MSSQL"],
///       "steps": [
///         { "wait": 3 },
///         { "action": "section", "server": "Test MSSQL", "target": "Security", "label": "switch-security" },
///         { "action": "folder", "server": "Test MSSQL", "target": "Logins" },
///         { "action": "collapse", "server": "Test MSSQL" },
///         { "action": "expand", "server": "Test MSSQL" },
///         { "action": "reveal", "server": "Test MSSQL" }
///       ]
///     }
///
/// `connect` names come from the automation config; they connect in this order and the steps
/// start once every one has its databases. Each step is an Instruments point of interest and a
/// timestamped line on stdout.
nonisolated struct AutomationScript: Codable, Sendable {
    struct Step: Codable, Sendable {
        /// `section`, `folder`, `collapse`, `expand` or `reveal`; `connect` connects `server` now;
        /// nil for a pure wait.
        var action: String?
        var server: String?
        /// The section's or folder's title.
        var target: String?
        /// Seconds to wait before the next step.
        var wait: Double?
        /// A name for the step in traces and logs.
        var label: String?
        /// `scroll`: points to scroll (negative scrolls up) and over how long.
        var distance: Double?
        var seconds: Double?
        /// `press`: the nth match (default the first) and a role to match (button, row, ...); `window` limits where steps look.
        var index: Int?
        var role: String?
        var window: String?
        /// `click`: where, in points from the top-left of the window (or sheet) as `Scripts/perf/axdump` prints it; `role` `right` for a
        /// right click, `index` for the click count.
        var x: Double?
        var y: Double?
    }

    var connect: [String]?
    var steps: [Step]

    static let pathEnvironmentKey = "ECHO_AUTOMATION_SCRIPT"

    static func load() -> AutomationScript? {
        guard let path = ProcessInfo.processInfo.environment[pathEnvironmentKey] else { return nil }
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AutomationScript.self, from: data)
    }
}

/// One step for the Explorer to perform, posted as a notification so the Explorer does it
/// through its own code paths, exactly as a click would.
struct ExplorerAutomationCommand {
    static let notification = Notification.Name("dev.echodb.echo.automation.explorer")

    let action: String
    let server: String
    let target: String?

    var userInfo: [String: String] {
        var info = ["action": action, "server": server]
        info["target"] = target
        return info
    }

    init(action: String, server: String, target: String?) {
        self.action = action
        self.server = server
        self.target = target
    }

    init?(_ notification: Notification) {
        guard let info = notification.userInfo as? [String: String], let action = info["action"], let server = info["server"] else { return nil }
        self.init(action: action, server: server, target: info["target"])
    }
}
#endif
