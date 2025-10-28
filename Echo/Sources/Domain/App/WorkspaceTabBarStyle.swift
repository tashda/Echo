import Foundation

enum WorkspaceTabBarStyle: String, Codable, CaseIterable, Hashable {
    case floating
    case toolbarCompact

    var displayName: String {
        switch self {
        case .floating:
            return "Floating Tab Bar"
        case .toolbarCompact:
            return "Toolbar Tabs"
        }
    }

    var showsFloatingStrip: Bool {
        switch self {
        case .floating:
            return true
        case .toolbarCompact:
            return false
        }
    }

    var maxVisibleToolbarTabs: Int {
        switch self {
        case .floating:
            return Int.max
        case .toolbarCompact:
            return Int.max
        }
    }
}
