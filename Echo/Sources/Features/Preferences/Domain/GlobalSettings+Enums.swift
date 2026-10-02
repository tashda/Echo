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

/// The server card's header: a banner with a line of capitals over a large name (round 53, F5) by
/// default. Round 30.1's five stay: a wash of colour (HD4, the default until round 53), plain
/// (HD0), a bar beside the name (HD12), the name on a glass plate (HD7) or a banner fading into
/// the card (HD16). What can be customised about the default is `ServerHeaderLook`.
enum ServerHeaderStyle: String, Codable, CaseIterable, Sendable {
    case titleBanner, wash, plain, bar, plate, banner
    var displayName: String {
        switch self {
        case .titleBanner: return "Banner with Title"
        case .wash: return "Wash"
        case .plain: return "Plain"
        case .bar: return "Bar"
        case .plate: return "Glass Plate"
        case .banner: return "Banner"
        }
    }
}

/// Where the server header's colour comes from (round 30.1): the server's own colour by default.
enum ServerHeaderColorSource: String, Codable, CaseIterable, Sendable {
    case none, server, accent
    var displayName: String {
        switch self {
        case .none: return "None"
        case .server: return "Server's Color"
        case .accent: return "Accent Color"
        }
    }
}

/// The colour of the section dock's current icon (round 30.1, DK1): the header's by default.
enum SidebarDockCurrentIconTint: String, Codable, CaseIterable, Sendable {
    case header, accent
    var displayName: String {
        switch self {
        case .header: return "Header's Color"
        case .accent: return "Accent Color"
        }
    }
}
