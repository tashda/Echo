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
        case .colorful: return "Colorful"
        case .monochrome: return "Monochrome"
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
