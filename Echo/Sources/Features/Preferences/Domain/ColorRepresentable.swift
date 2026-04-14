import SwiftUI

struct ColorRepresentable: Codable, Equatable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }

    init(color: Color) {
#if os(macOS)
        let converted = PlatformColorConverter.shared.rgbaComponents(from: color)
        red = converted.red
        green = converted.green
        blue = converted.blue
        alpha = converted.alpha
#else
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        red = Double(r)
        green = Double(g)
        blue = Double(b)
        alpha = Double(a)
#endif
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }

#if os(macOS)
    var nsColor: NSColor {
        PlatformColorConverter.shared.color(red: red, green: green, blue: blue, alpha: alpha)
    }
#else
    var uiColor: UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
#endif

    func withAlpha(_ alpha: Double) -> ColorRepresentable {
        ColorRepresentable(red: red, green: green, blue: blue, alpha: alpha)
    }

    func blended(with other: ColorRepresentable, fraction: Double) -> ColorRepresentable {
        let t = max(0.0, min(1.0, fraction))
        let blendedRed = red + (other.red - red) * t
        let blendedGreen = green + (other.green - green) * t
        let blendedBlue = blue + (other.blue - blue) * t
        let blendedAlpha = alpha + (other.alpha - alpha) * t
        return ColorRepresentable(red: blendedRed, green: blendedGreen, blue: blendedBlue, alpha: blendedAlpha)
    }
}
