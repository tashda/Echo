import SwiftUI
import AppKit

extension ServerColorPalette {
    /// A saved colour as a SwiftUI colour. A palette colour is dynamic: its light value in light
    /// appearance, its dark value in dark. Anything else is the colour as saved.
    static func swiftUIColor(forStored hex: String) -> Color? {
        guard let entry = color(forStored: hex) else { return Color(hex: hex) }
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let value = entry.value(isDark: isDark)
            return NSColor(srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        })
    }
}
