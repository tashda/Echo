import AppKit
import SwiftUI

/// Round 28: Echo's default editor palettes, copied from `SQLEditorPalette+Light/Dark` (Aurora in
/// light, Midnight in dark), so the specimens show the colours Echo draws today.
struct LabQEPalette {
    let keyword: Color
    let string: Color
    let number: Color
    let comment: Color
    let plain: Color
    let function: Color
    let operatorSymbol: Color
    let gutterBackground: Color
    let gutterText: Color
    /// The colour Echo gives the caret line's number today (Aurora #D9D9DC, Midnight #2D2D30).
    let gutterAccent: Color
    let selection: Color
    let currentLine: Color

    static let echo = LabQEPalette(
        keyword: pair(0x0000FF, 0xC586C0), string: pair(0xA31515, 0xCE9178), number: pair(0x098658, 0xB5CEA8),
        comment: pair(0x008000, 0x6A9955), plain: pair(0x1E1E1E, 0xD4D4D4), function: pair(0x795E26, 0xDCDCAA),
        operatorSymbol: pair(0x1B1B1B, 0x569CD6), gutterBackground: pair(0xF3F4F6, 0x252526),
        gutterText: pair(0x6D6D6D, 0x858585), gutterAccent: pair(0xD9D9DC, 0x2D2D30),
        selection: pair(0xCCE8FF, 0x264F78, lightAlpha: 0.85, darkAlpha: 0.9), currentLine: pair(0xF3F3F3, 0x2A2A2A))

    func color(for kind: LabQEToken.Kind) -> Color {
        switch kind {
        case .keyword: keyword
        case .string: string
        case .number: number
        case .comment: comment
        case .function: function
        case .symbol: operatorSymbol
        case .plain: plain
        }
    }

    private static func pair(_ light: Int, _ dark: Int, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        .adaptive(light: nsColor(light, alpha: lightAlpha), dark: nsColor(dark, alpha: darkAlpha))
    }

    private static func nsColor(_ hex: Int, alpha: CGFloat) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }
}
