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

enum SidebarIconColorMode: String, Codable, CaseIterable, Sendable {
    case colorful, monochrome
    var displayName: String {
        switch self {
        case .colorful: return "Duotone"
        case .monochrome: return "Mono"
        }
    }
}

/// The section dock's icons (round 16): mono (grey, the current one in the accent colour) or
/// duotone like the tree's.
enum SidebarDockIconStyle: String, Codable, CaseIterable, Sendable {
    case mono, duotone
    var displayName: String {
        switch self {
        case .mono: return "Mono"
        case .duotone: return "Duotone"
        }
    }
}

enum SidebarIconSize: String, Codable, CaseIterable, Sendable {
    case small, medium, large
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum SidebarDensity: String, Codable, CaseIterable, Sendable {
    case compact, small, medium, large
    var displayName: String {
        switch self {
        case .compact: return "Compact"
        case .small: return "Small"
        case .medium: return "Default"
        case .large: return "Large"
        }
    }
}
