#if DEBUG
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
            if step.action == "scroll" {
                announce(index: index, label: step.label ?? "scroll \(step.target ?? "")")
                await performAutomationScroll(target: step.target ?? "sidebar", distance: step.distance ?? 800, seconds: step.seconds ?? 1)
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
            if let wait = step.wait { try? await Task.sleep(for: .seconds(wait)) }
        }
        print("automation-script end \(String(format: "%.3f", Date().timeIntervalSince1970))")
        fflush(stdout)
        Self.scriptLogger.info("Automation script finished")
    }

    private func announce(index: Int, label: String) {
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
