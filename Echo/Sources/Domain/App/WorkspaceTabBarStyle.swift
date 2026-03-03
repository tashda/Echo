import Foundation

enum WorkspaceTabBarStyle: String, Codable, CaseIterable, Hashable {
    case floating

    var displayName: String { "Floating Tab Bar" }
    var showsFloatingStrip: Bool { true }
    var maxVisibleToolbarTabs: Int { Int.max }
}

// Backward-compatible decoding: map any previously stored values (e.g. "toolbarCompact") to `.floating`.
extension WorkspaceTabBarStyle {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "floating"
        self = WorkspaceTabBarStyle(rawValue: raw) ?? .floating
        if self != .floating { self = .floating }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("floating")
    }
}
