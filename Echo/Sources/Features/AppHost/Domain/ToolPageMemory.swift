import Foundation

/// The last page used in each tool on each server (round 36.2, RM0): a tool reopens on it.
struct ToolPageMemory {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func page(tool: String, connectionID: UUID) -> String? {
        defaults.string(forKey: Self.key(tool: tool, connectionID: connectionID))
    }

    func remember(_ page: String, tool: String, connectionID: UUID) {
        defaults.set(page, forKey: Self.key(tool: tool, connectionID: connectionID))
    }

    static func key(tool: String, connectionID: UUID) -> String {
        "toolPage.\(tool).\(connectionID.uuidString)"
    }
}
