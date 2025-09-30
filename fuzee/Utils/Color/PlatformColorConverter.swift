import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct PlatformRGBAComponents: Equatable, Codable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
}

final class PlatformColorConverter {
    static let shared = PlatformColorConverter()

    private init() {}

#if os(macOS)
    private lazy var deviceRGB = CGColorSpaceCreateDeviceRGB()

    func rgbaComponents(from color: Color) -> PlatformRGBAComponents {
        var nsColor = NSColor(color)

        if let device = nsColor.usingColorSpace(.deviceRGB) {
            nsColor = device
            return PlatformRGBAComponents(
                red: Double(nsColor.redComponent),
                green: Double(nsColor.greenComponent),
                blue: Double(nsColor.blueComponent),
                alpha: Double(nsColor.alphaComponent)
            )
        }

        let cgColor = nsColor.cgColor

        if let converted = cgColor.converted(to: deviceRGB, intent: .defaultIntent, options: nil),
           let comps = converted.components,
           comps.count >= 4 {
            return PlatformRGBAComponents(
                red: Double(comps[0]),
                green: Double(comps[1]),
                blue: Double(comps[2]),
                alpha: Double(comps[3])
            )
        }

        if let fallback = NSColor.labelColor.usingColorSpace(.deviceRGB) {
            return PlatformRGBAComponents(
                red: Double(fallback.redComponent),
                green: Double(fallback.greenComponent),
                blue: Double(fallback.blueComponent),
                alpha: Double(fallback.alphaComponent)
            )
        }

        return PlatformRGBAComponents(red: 0.15, green: 0.15, blue: 0.18, alpha: 1.0)
    }

    func color(red: Double, green: Double, blue: Double, alpha: Double) -> NSColor {
        NSColor(deviceRed: red, green: green, blue: blue, alpha: alpha)
    }
#else
    func rgbaComponents(from color: Color) -> PlatformRGBAComponents {
        let uiColor = UIColor(color)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return PlatformRGBAComponents(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
    }

    func color(red: Double, green: Double, blue: Double, alpha: Double) -> UIColor {
        UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
#endif
}
