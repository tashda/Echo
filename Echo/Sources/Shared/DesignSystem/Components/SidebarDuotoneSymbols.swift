import AppKit
import SwiftUI

extension EnvironmentValues {
    /// Sidebar rows draw their SF Symbols duotone (IC2): on in colourful icon mode, off in mono.
    @Entry var sidebarUsesDuotoneIcons = false
}

/// Finds a symbol's `.fill` variant for duotone rows. A symbol without one draws its outline
/// only; a missing symbol would render as nothing, so each name is checked once and cached.
@MainActor
enum SidebarDuotoneSymbols {
    static let fillOpacity = 0.22
    private static var cache: [String: String?] = [:]

    static func fillName(for name: String) -> String? {
        if let cached = cache[name] { return cached }
        let candidate = name.hasSuffix(".fill") ? nil : "\(name).fill"
        let resolved = candidate.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) != nil ? $0 : nil }
        cache[name] = resolved
        return resolved
    }
}
