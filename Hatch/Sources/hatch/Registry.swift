import Foundation

/// Commands that need the other modules (Sync, Git, Agent, API, Import). Added as those modules land.
enum Registry {
    static func extra() -> [String: Handler] { [:] }
}
