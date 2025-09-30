import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SQLEditorTheme: Codable, Equatable {
    struct TokenColors: Codable, Equatable {
        var keyword: ColorRepresentable
        var string: ColorRepresentable
        var number: ColorRepresentable
        var comment: ColorRepresentable
        var plain: ColorRepresentable

        static let `default` = TokenColors(
            keyword: ColorRepresentable(color: Color(red: 0.38, green: 0.55, blue: 0.96)),
            string: ColorRepresentable(color: Color(red: 0.79, green: 0.44, blue: 0.86)),
            number: ColorRepresentable(color: Color(red: 0.96, green: 0.62, blue: 0.3)),
            comment: ColorRepresentable(color: Color(red: 0.48, green: 0.52, blue: 0.58)),
            plain: ColorRepresentable(color: Color.primary)
        )
    }

    var fontName: String
    var fontSize: CGFloat
    var tokenColors: TokenColors

    init(
        fontName: String = "SFMono-Regular",
        fontSize: CGFloat = 15,
        tokenColors: TokenColors = .default
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.tokenColors = tokenColors
    }

    var font: NSFontWithFallback {
        NSFontWithFallback(name: fontName, size: fontSize)
    }

#if os(macOS)
    var nsFont: NSFont {
        font.font
    }
#else
    var uiFont: UIFont {
        font.font
    }
#endif
}

struct ColorRepresentable: Codable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

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
}

struct NSFontWithFallback {
    var name: String
    var size: CGFloat

    init(name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

#if os(macOS)
    var font: NSFont {
        NSFont(name: name, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#else
    var font: UIFont {
        UIFont(name: name, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#endif
}
