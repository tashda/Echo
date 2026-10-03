import Foundation

/// Commands that need the other modules (Sync, Git, Agent, API, Import).
enum Registry {
    static func extra() -> [String: Handler] { AgentCommands.all }
}
