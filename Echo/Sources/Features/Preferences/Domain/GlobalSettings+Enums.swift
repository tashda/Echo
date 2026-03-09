import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case light, dark, system
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum ForeignKeyDisplayMode: String, Codable, CaseIterable, Hashable, Sendable {
    case showInspector, showIcon, disabled
}

enum ForeignKeyInspectorBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case respectInspectorVisibility, autoOpenAndClose
}
