import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension Color {
    /// Initializes a `Color` from a hexadecimal string.
    /// - Parameter hex: The hex string (e.g., "#FF5733", "FF5733", "F53", or "FF5733AA").
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// Converts the `Color` to a hexadecimal string representation.
    /// - Returns: A hex string (e.g., "#FF5733") or `nil` if the color components cannot be read.
    func toHex() -> String? {
        guard let components = self.components else {
            return nil
        }
        return String(format: "#%02X%02X%02X", Int(components.r * 255), Int(components.g * 255), Int(components.b * 255))
    }

    /// Calculates a contrasting foreground color (black or white) for the current color.
    /// This is useful for ensuring text or icons are legible on a colored background.
    var contrastingForegroundColor: Color {
        guard let components = self.components else {
            return .primary
        }
        
        // Using the luminance formula to determine brightness
        let luminance = (0.299 * components.r + 0.587 * components.g + 0.114 * components.b)
        
        return luminance > 0.6 ? .black : .white
    }

    /// A private helper to get the RGBA components of the color, handling platform differences.
    private var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        #if os(macOS)
        // On macOS, convert to NSColor in sRGB space to get components.
        guard let sRGBColor = PlatformColor2(self).usingColorSpace(.sRGB),
              let components = sRGBColor.cgColor.components,
              components.count >= 3 else {
            return nil
        }
        return (components[0], components[1], components[2], sRGBColor.alphaComponent)
        #else
        // On iOS/iPadOS, use UIColor's getRed(_:green:blue:alpha:) method.
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        guard PlatformColor2(self).getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        return (r, g, b, a)
        #endif
    }
}
