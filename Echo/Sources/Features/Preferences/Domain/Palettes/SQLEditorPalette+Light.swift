import SwiftUI

extension SQLEditorPalette {
    static let echoLight = SQLEditorPalette(
        id: "echo-light",
        name: "Echo Light",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x1C1C1E),
        gutterBackground: ColorRepresentable(hex: 0xEEF1F6),
        gutterText: ColorRepresentable(hex: 0x8E8E93),
        gutterAccent: ColorRepresentable(hex: 0xD7DAE1),
        selection: ColorRepresentable(hex: 0xD6E8FF, alpha: 0.78),
        currentLine: ColorRepresentable(hex: 0xF5F7FE),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x056CF2),
            string: ColorRepresentable(hex: 0x0F8F6A),
            number: ColorRepresentable(hex: 0xCE8A22),
            comment: ColorRepresentable(hex: 0x8E8E93),
            plain: ColorRepresentable(hex: 0x1C1C1E),
            function: ColorRepresentable(hex: 0x3E4CA3),
            operatorSymbol: ColorRepresentable(hex: 0x2C5CC5),
            identifier: ColorRepresentable(hex: 0x1F6CAD)
        )
    )

    static let aurora = SQLEditorPalette(
        id: "aurora",
        name: "Aurora",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x1E1E1E),
        gutterBackground: ColorRepresentable(hex: 0xF3F4F6),
        gutterText: ColorRepresentable(hex: 0x6D6D6D),
        gutterAccent: ColorRepresentable(hex: 0xD9D9DC),
        selection: ColorRepresentable(hex: 0xCCE8FF, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xF3F3F3),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x0000FF),
            string: ColorRepresentable(hex: 0xA31515),
            number: ColorRepresentable(hex: 0x098658),
            comment: ColorRepresentable(hex: 0x008000),
            plain: ColorRepresentable(hex: 0x1E1E1E),
            function: ColorRepresentable(hex: 0x795E26),
            operatorSymbol: ColorRepresentable(hex: 0x1B1B1B),
            identifier: ColorRepresentable(hex: 0x267F99)
        )
    )

    static let solstice = SQLEditorPalette(
        id: "solstice",
        name: "Solstice",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x586E75),
        gutterBackground: ColorRepresentable(hex: 0xF5F1E4),
        gutterText: ColorRepresentable(hex: 0x7F8C8D),
        gutterAccent: ColorRepresentable(hex: 0xD1C7A3),
        selection: ColorRepresentable(hex: 0xC4DBE8, alpha: 0.8),
        currentLine: ColorRepresentable(hex: 0xE8DFC8),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x268BD2),
            string: ColorRepresentable(hex: 0x2AA198),
            number: ColorRepresentable(hex: 0xB58900),
            comment: ColorRepresentable(hex: 0x93A1A1),
            plain: ColorRepresentable(hex: 0x586E75),
            function: ColorRepresentable(hex: 0x6C71C4),
            operatorSymbol: ColorRepresentable(hex: 0xDC322F),
            identifier: ColorRepresentable(hex: 0x657B83)
        )
    )

    static let githubLight = SQLEditorPalette(
        id: "github-light",
        name: "GitHub Light",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x24292E),
        gutterBackground: ColorRepresentable(hex: 0xF6F8FA),
        gutterText: ColorRepresentable(hex: 0x6E7781),
        gutterAccent: ColorRepresentable(hex: 0xD0D7DE),
        selection: ColorRepresentable(hex: 0xBFD4FF, alpha: 0.65),
        currentLine: ColorRepresentable(hex: 0xEAECEF),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x0550AE),
            string: ColorRepresentable(hex: 0x116329),
            number: ColorRepresentable(hex: 0x953800),
            comment: ColorRepresentable(hex: 0x8B949E),
            plain: ColorRepresentable(hex: 0x24292E),
            function: ColorRepresentable(hex: 0x0F6CBD),
            operatorSymbol: ColorRepresentable(hex: 0xCF222E),
            identifier: ColorRepresentable(hex: 0x4C2889)
        )
    )

    static let catppuccinLatte = SQLEditorPalette(
        id: "catppuccin-latte",
        name: "Catppuccin Latte",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xEFF1F5),
        text: ColorRepresentable(hex: 0x4C4F69),
        gutterBackground: ColorRepresentable(hex: 0xE6E9EF),
        gutterText: ColorRepresentable(hex: 0x5C5F77),
        gutterAccent: ColorRepresentable(hex: 0xBCC0CC),
        selection: ColorRepresentable(hex: 0xCCD0DA, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xDCE0E8),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x7287FD),
            string: ColorRepresentable(hex: 0x40A02B),
            number: ColorRepresentable(hex: 0xDF8E1D),
            comment: ColorRepresentable(hex: 0x6C6F85),
            plain: ColorRepresentable(hex: 0x4C4F69),
            function: ColorRepresentable(hex: 0x209FB5),
            operatorSymbol: ColorRepresentable(hex: 0xE64553),
            identifier: ColorRepresentable(hex: 0x1E66F5)
        )
    )

    static let emberLight = SQLEditorPalette(
        id: "ember-light",
        name: "Ember Light",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFF8F3),
        text: ColorRepresentable(hex: 0x2A1F14),
        gutterBackground: ColorRepresentable(hex: 0xF4E5D8),
        gutterText: ColorRepresentable(hex: 0xA1846A),
        gutterAccent: ColorRepresentable(hex: 0xD4B79A),
        selection: ColorRepresentable(hex: 0xFCD9C2, alpha: 0.8),
        currentLine: ColorRepresentable(hex: 0xF9E7D7),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xC25A2B),
            string: ColorRepresentable(hex: 0x458639),
            number: ColorRepresentable(hex: 0xAF5F1C),
            comment: ColorRepresentable(hex: 0xAD9C8E),
            plain: ColorRepresentable(hex: 0x2A1F14),
            function: ColorRepresentable(hex: 0xA33EA1),
            operatorSymbol: ColorRepresentable(hex: 0xD04F4F),
            identifier: ColorRepresentable(hex: 0x2F4F7C)
        )
    )

    static let seaBreeze = SQLEditorPalette(
        id: "sea-breeze",
        name: "Sea Breeze",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xF1FBFF),
        text: ColorRepresentable(hex: 0x1C2E3A),
        gutterBackground: ColorRepresentable(hex: 0xE1F1F7),
        gutterText: ColorRepresentable(hex: 0x587482),
        gutterAccent: ColorRepresentable(hex: 0xBBD8E6),
        selection: ColorRepresentable(hex: 0xC9E8FF, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xE7F4FA),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x0A75C2),
            string: ColorRepresentable(hex: 0x1E8B6F),
            number: ColorRepresentable(hex: 0xAA5B00),
            comment: ColorRepresentable(hex: 0x7AA0B0),
            plain: ColorRepresentable(hex: 0x1C2E3A),
            function: ColorRepresentable(hex: 0x4167D9),
            operatorSymbol: ColorRepresentable(hex: 0xCF3F5E),
            identifier: ColorRepresentable(hex: 0x2F5872)
        )
    )

    static let orchard = SQLEditorPalette(
        id: "orchard",
        name: "Orchard",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xECEFF4),
        text: ColorRepresentable(hex: 0x2E3440),
        gutterBackground: ColorRepresentable(hex: 0xD8DEE9),
        gutterText: ColorRepresentable(hex: 0x4C566A),
        gutterAccent: ColorRepresentable(hex: 0xCBD6E2),
        selection: ColorRepresentable(hex: 0xE5EEF6, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xDEE6F0),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x5E81AC),
            string: ColorRepresentable(hex: 0xA3BE8C),
            number: ColorRepresentable(hex: 0xEBCB8B),
            comment: ColorRepresentable(hex: 0x7D8899),
            plain: ColorRepresentable(hex: 0x2E3440),
            function: ColorRepresentable(hex: 0x81A1C1),
            operatorSymbol: ColorRepresentable(hex: 0xBF616A),
            identifier: ColorRepresentable(hex: 0x88C0D0)
        )
    )

    static let paperwhite = SQLEditorPalette(
        id: "paperwhite",
        name: "Paperwhite",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFAFAFA),
        text: ColorRepresentable(hex: 0x383A42),
        gutterBackground: ColorRepresentable(hex: 0xEDEEED),
        gutterText: ColorRepresentable(hex: 0x8B9098),
        gutterAccent: ColorRepresentable(hex: 0xCFD0D4),
        selection: ColorRepresentable(hex: 0xE0E8FF, alpha: 0.82),
        currentLine: ColorRepresentable(hex: 0xF1F2F4),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xA626A4),
            string: ColorRepresentable(hex: 0x50A14F),
            number: ColorRepresentable(hex: 0x986801),
            comment: ColorRepresentable(hex: 0xA0A1A7),
            plain: ColorRepresentable(hex: 0x383A42),
            function: ColorRepresentable(hex: 0x4078F2),
            operatorSymbol: ColorRepresentable(hex: 0x0184BC),
            identifier: ColorRepresentable(hex: 0xE45649)
        )
    )
}
