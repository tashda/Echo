import AppKit
import SwiftUI

extension Color {
    /// A colour that follows the window's appearance: light and dark, plus stronger values when
    /// Increase Contrast is on. Use it for fills that can't be a system colour.
    public static func adaptive(
        light: NSColor,
        dark: NSColor,
        highContrastLight: NSColor? = nil,
        highContrastDark: NSColor? = nil
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            switch appearance.bestMatch(from: [
                .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua,
            ]) {
            case .darkAqua: return dark
            case .accessibilityHighContrastAqua: return highContrastLight ?? light
            case .accessibilityHighContrastDarkAqua: return highContrastDark ?? dark
            default: return light
            }
        })
    }
}
