#if DEBUG
import AppKit
import Foundation
import OSLog

extension AppDirector {
    private static let scriptLogger = Logger(subsystem: "dev.echodb.echo", category: "automation")
    /// Steps show as points of interest in any Instruments template.
    private static let scriptSignposter = OSSignposter(subsystem: "dev.echodb.echo", category: .pointsOfInterest)

    /// Connects the script's servers in order, waits for their databases, then performs its steps.
    func runAutomationScript(_ script: AutomationScript, connections: [String: SavedConnection]) async {
        for name in script.connect ?? [] {
            guard let connection = connections[name] else { continue }
            if environmentState.sessionGroup.sessionForConnection(connection.id) == nil {
                environmentState.connect(to: connection)
            }
            await waitForDatabases(of: connection)
        }
        let start = Date()
        print("automation-script start \(String(format: "%.3f", start.timeIntervalSince1970))")
        for (index, step) in script.steps.enumerated() {
            await performAutomationStep(step, index: index, connections: connections)
            if let wait = step.wait { try? await Task.sleep(for: .seconds(wait)) }
        }
        if let commands = ProcessInfo.processInfo.environment["ECHO_AUTOMATION_COMMANDS"] {
            await listenForAutomationCommands(at: commands, connections: connections)
        }
        print("automation-script end \(String(format: "%.3f", Date().timeIntervalSince1970))")
        fflush(stdout)
        Self.scriptLogger.info("Automation script finished")
    }

    /// One step, as the script runs it.
    func performAutomationStep(_ step: AutomationScript.Step, index: Int, connections: [String: SavedConnection]) async {
        AutomationFocusGuard.stepStarted()
        if step.action == "type" {
            announce(index: index, label: step.label ?? "type")
            await performAutomationTyping(step.target ?? "", interval: step.seconds ?? 0.12)
        } else if step.action == "fill" {
            announce(index: index, label: step.label ?? "fill \(step.target ?? "")")
            performAutomationFill(lines: Int(step.target ?? "") ?? 1000)
        } else if step.action == "resize" {
            announce(index: index, label: step.label ?? "resize \(step.distance ?? 0)")
            await performAutomationResize(distance: step.distance ?? -300, seconds: step.seconds ?? 1)
        } else if step.action == "scroll" {
            announce(index: index, label: step.label ?? "scroll \(step.target ?? "")")
            await performAutomationScroll(target: step.target ?? "sidebar", distance: step.distance ?? 800, seconds: step.seconds ?? 1)
        } else if let action = step.action, ["axOn", "dumpUI", "press", "key", "fieldType", "click", "frames"].contains(action) {
            announce(index: index, label: step.label ?? "\(action) \(step.target ?? "")")
            await performUIAutomationStep(step)
        } else if let action = step.action, Self.appAutomationActions.contains(action) {
            announce(index: index, label: step.label ?? "\(action) \(step.target ?? step.server ?? "")")
            performAppAutomationStep(step, connections: connections)
        } else if let action = step.action, let server = step.server {
            announce(index: index, label: step.label ?? "\(action) \(step.target ?? server)")
            NotificationCenter.default.post(
                name: ExplorerAutomationCommand.notification, object: nil,
                userInfo: ExplorerAutomationCommand(action: action, server: server, target: step.target).userInfo
            )
        }
    }

    /// Steps appended to a file, one JSON step per line, run as they arrive (`ECHO_AUTOMATION_COMMANDS`), so a
    /// session can be driven step by step while looking at the window between steps. `{"action":"quit"}` ends it.
    private func listenForAutomationCommands(at path: String, connections: [String: SavedConnection]) async {
        var done = 0
        print("automation-commands listening \(path)"); fflush(stdout)
        while true {
            let lines = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
            if lines.count > done {
                for line in lines[done...] {
                    done += 1
                    guard let data = line.data(using: .utf8), let step = try? JSONDecoder().decode(AutomationScript.Step.self, from: data) else {
                        print("automation-commands cannot read: \(line)"); fflush(stdout); continue
                    }
                    if step.action == "quit" { NSApp.terminate(nil); return }
                    await performAutomationStep(step, index: done, connections: connections)
                    if let wait = step.wait { try? await Task.sleep(for: .seconds(wait)) }
                    print("automation-commands done \(done)"); fflush(stdout)
                }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// A point of interest for one moment inside a step, such as a keystroke.
    static func markAutomationEvent(_ label: String) {
        scriptSignposter.emitEvent("key", "\(label, privacy: .public)")
    }

    private func announce(index: Int, label: String) {
        AutomationFrameMeter.shared.begin(step: "\(index) \(label)")
        Self.scriptSignposter.emitEvent("step", "\(index) \(label, privacy: .public)")
        print("automation-step \(String(format: "%.3f", Date().timeIntervalSince1970)) \(index) \(label)")
        fflush(stdout)
    }

    private func waitForDatabases(of connection: SavedConnection) async {
        for _ in 0..<120 {
            if let session = environmentState.sessionGroup.sessionForConnection(connection.id), session.databaseStructure != nil { return }
            try? await Task.sleep(for: .milliseconds(500))
        }
        Self.scriptLogger.error("Automation script timed out waiting for \(connection.connectionName, privacy: .public)")
    }
}
#endif
