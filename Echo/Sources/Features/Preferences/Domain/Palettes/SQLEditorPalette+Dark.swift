import SwiftUI

extension SQLEditorPalette {
    static let echoDark = SQLEditorPalette(
        id: "echo-dark",
        name: "Echo Dark",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x1D1E27),
        text: ColorRepresentable(hex: 0xE9E9EC),
        gutterBackground: ColorRepresentable(hex: 0x161721),
        gutterText: ColorRepresentable(hex: 0x7A7A86),
        gutterAccent: ColorRepresentable(hex: 0x2D3039),
        selection: ColorRepresentable(hex: 0x2E3A50, alpha: 0.78),
        currentLine: ColorRepresentable(hex: 0x252631),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x87B7FF),
            string: ColorRepresentable(hex: 0x7FD8B8),
            number: ColorRepresentable(hex: 0xFFC86B),
            comment: ColorRepresentable(hex: 0x7A7A86),
            plain: ColorRepresentable(hex: 0xE9E9EC),
            function: ColorRepresentable(hex: 0xA7C6FF),
            operatorSymbol: ColorRepresentable(hex: 0x5CAFFF),
            identifier: ColorRepresentable(hex: 0x8AD6FF)
        )
    )

    static let midnight = SQLEditorPalette(
        id: "midnight",
        name: "Midnight",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x1E1E1E),
        text: ColorRepresentable(hex: 0xD4D4D4),
        gutterBackground: ColorRepresentable(hex: 0x252526),
        gutterText: ColorRepresentable(hex: 0x858585),
        gutterAccent: ColorRepresentable(hex: 0x2D2D30),
        selection: ColorRepresentable(hex: 0x264F78, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x2A2A2A),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xC586C0),
            string: ColorRepresentable(hex: 0xCE9178),
            number: ColorRepresentable(hex: 0xB5CEA8),
            comment: ColorRepresentable(hex: 0x6A9955),
            plain: ColorRepresentable(hex: 0xD4D4D4),
            function: ColorRepresentable(hex: 0xDCDCAA),
            operatorSymbol: ColorRepresentable(hex: 0x569CD6),
            identifier: ColorRepresentable(hex: 0x9CDCFE)
        )
    )

    static let oneDark = SQLEditorPalette(
        id: "one-dark",
        name: "One Dark",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x282C34),
        text: ColorRepresentable(hex: 0xABB2BF),
        gutterBackground: ColorRepresentable(hex: 0x21252B),
        gutterText: ColorRepresentable(hex: 0x7F848E),
        gutterAccent: ColorRepresentable(hex: 0x2C313C),
        selection: ColorRepresentable(hex: 0x3E4451, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x2C313C),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xC678DD),
            string: ColorRepresentable(hex: 0x98C379),
            number: ColorRepresentable(hex: 0xD19A66),
            comment: ColorRepresentable(hex: 0x5C6370),
            plain: ColorRepresentable(hex: 0xABB2BF),
            function: ColorRepresentable(hex: 0x61AFEF),
            operatorSymbol: ColorRepresentable(hex: 0xE06C75),
            identifier: ColorRepresentable(hex: 0xE5C07B)
        )
    )

    static let dracula = SQLEditorPalette(
        id: "dracula",
        name: "Dracula",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x282A36),
        text: ColorRepresentable(hex: 0xF8F8F2),
        gutterBackground: ColorRepresentable(hex: 0x21222C),
        gutterText: ColorRepresentable(hex: 0x6272A4),
        gutterAccent: ColorRepresentable(hex: 0x44475A),
        selection: ColorRepresentable(hex: 0x44475A, alpha: 0.92),
        currentLine: ColorRepresentable(hex: 0x343746),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xFF79C6),
            string: ColorRepresentable(hex: 0xF1FA8C),
            number: ColorRepresentable(hex: 0xBD93F9),
            comment: ColorRepresentable(hex: 0x6272A4),
            plain: ColorRepresentable(hex: 0xF8F8F2),
            function: ColorRepresentable(hex: 0x50FA7B),
            operatorSymbol: ColorRepresentable(hex: 0xFFB86C),
            identifier: ColorRepresentable(hex: 0x8BE9FD)
        )
    )

    static let nebulaNight = SQLEditorPalette(
        id: "nebula-night",
        name: "Nebula Night",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x101423),
        text: ColorRepresentable(hex: 0xE3E7F7),
        gutterBackground: ColorRepresentable(hex: 0x151A2C),
        gutterText: ColorRepresentable(hex: 0x5E6A89),
        gutterAccent: ColorRepresentable(hex: 0x273250),
        selection: ColorRepresentable(hex: 0x24345C, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x1C2540),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x8DA5FF),
            string: ColorRepresentable(hex: 0x4FDEA3),
            number: ColorRepresentable(hex: 0xFFB86B),
            comment: ColorRepresentable(hex: 0x5D6A85),
            plain: ColorRepresentable(hex: 0xE3E7F7),
            function: ColorRepresentable(hex: 0x9F7BFF),
            operatorSymbol: ColorRepresentable(hex: 0xFF6B91),
            identifier: ColorRepresentable(hex: 0x7ACEFF)
        )
    )

    static let emberDark = SQLEditorPalette(
        id: "ember-dark",
        name: "Ember Dark",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x272822),
        text: ColorRepresentable(hex: 0xF8F8F2),
        gutterBackground: ColorRepresentable(hex: 0x2F2E29),
        gutterText: ColorRepresentable(hex: 0x9D9D91),
        gutterAccent: ColorRepresentable(hex: 0x3B3A32),
        selection: ColorRepresentable(hex: 0x49483E, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x3B3A32),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xF92672),
            string: ColorRepresentable(hex: 0xE6DB74),
            number: ColorRepresentable(hex: 0xAE81FF),
            comment: ColorRepresentable(hex: 0x75715E),
            plain: ColorRepresentable(hex: 0xF8F8F2),
            function: ColorRepresentable(hex: 0x66D9EF),
            operatorSymbol: ColorRepresentable(hex: 0xFD971F),
            identifier: ColorRepresentable(hex: 0xA6E22E)
        )
    )

    static let charcoal = SQLEditorPalette(
        id: "charcoal",
        name: "Charcoal",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x16161E),
        text: ColorRepresentable(hex: 0xD8DEE6),
        gutterBackground: ColorRepresentable(hex: 0x1F1F2A),
        gutterText: ColorRepresentable(hex: 0x6B7285),
        gutterAccent: ColorRepresentable(hex: 0x2A2B38),
        selection: ColorRepresentable(hex: 0x1F2533, alpha: 0.92),
        currentLine: ColorRepresentable(hex: 0x20222F),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x5DA9F6),
            string: ColorRepresentable(hex: 0x4BD0A0),
            number: ColorRepresentable(hex: 0xF2A65A),
            comment: ColorRepresentable(hex: 0x606B7D),
            plain: ColorRepresentable(hex: 0xD8DEE6),
            function: ColorRepresentable(hex: 0x7D8CFF),
            operatorSymbol: ColorRepresentable(hex: 0xF5546B),
            identifier: ColorRepresentable(hex: 0x8AD1FF)
        )
    )

    static let catppuccinMocha = SQLEditorPalette(
        id: "catppuccin-mocha",
        name: "Catppuccin Mocha",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x1E1E2E),
        text: ColorRepresentable(hex: 0xCDD6F4),
        gutterBackground: ColorRepresentable(hex: 0x242438),
        gutterText: ColorRepresentable(hex: 0x8388B5),
        gutterAccent: ColorRepresentable(hex: 0x2D2D45),
        selection: ColorRepresentable(hex: 0x3A3A58, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x2A2A40),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xCBA6F7),
            string: ColorRepresentable(hex: 0xA6E3A1),
            number: ColorRepresentable(hex: 0xF5C2E7),
            comment: ColorRepresentable(hex: 0x6E738D),
            plain: ColorRepresentable(hex: 0xCDD6F4),
            function: ColorRepresentable(hex: 0x94E2D5),
            operatorSymbol: ColorRepresentable(hex: 0xF5C2E7),
            identifier: ColorRepresentable(hex: 0x89B4FA)
        )
    )

    static let solarizedDark = SQLEditorPalette(
        id: "solarized-dark",
        name: "Solarized Dark",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x002B36),
        text: ColorRepresentable(hex: 0x839496),
        gutterBackground: ColorRepresentable(hex: 0x01313C),
        gutterText: ColorRepresentable(hex: 0x586E75),
        gutterAccent: ColorRepresentable(hex: 0x0A3944),
        selection: ColorRepresentable(hex: 0x073642, alpha: 0.92),
        currentLine: ColorRepresentable(hex: 0x003541),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x859900),
            string: ColorRepresentable(hex: 0x2AA198),
            number: ColorRepresentable(hex: 0xD33682),
            comment: ColorRepresentable(hex: 0x586E75),
            plain: ColorRepresentable(hex: 0x93A1A1),
            function: ColorRepresentable(hex: 0x268BD2),
            operatorSymbol: ColorRepresentable(hex: 0xB58900),
            identifier: ColorRepresentable(hex: 0xCB4B16)
        )
    )

    static let violetStorm = SQLEditorPalette(
        id: "violet-storm",
        name: "Violet Storm",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x17122A),
        text: ColorRepresentable(hex: 0xF2ECFF),
        gutterBackground: ColorRepresentable(hex: 0x1F1A35),
        gutterText: ColorRepresentable(hex: 0x7F72A4),
        gutterAccent: ColorRepresentable(hex: 0x2B2444),
        selection: ColorRepresentable(hex: 0x332A52, alpha: 0.92),
        currentLine: ColorRepresentable(hex: 0x241E40),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xC299FF),
            string: ColorRepresentable(hex: 0x7DE2CF),
            number: ColorRepresentable(hex: 0xF2A3F8),
            comment: ColorRepresentable(hex: 0x7F72A4),
            plain: ColorRepresentable(hex: 0xF2ECFF),
            function: ColorRepresentable(hex: 0x8FABFF),
            operatorSymbol: ColorRepresentable(hex: 0xFF6ED1),
            identifier: ColorRepresentable(hex: 0xB0C3FF)
        )
    )

    static let nord = SQLEditorPalette(
        id: "nord",
        name: "Nord",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x2E3440),
        text: ColorRepresentable(hex: 0xECEFF4),
        gutterBackground: ColorRepresentable(hex: 0x292F3B),
        gutterText: ColorRepresentable(hex: 0x616E88),
        gutterAccent: ColorRepresentable(hex: 0x3B4252),
        selection: ColorRepresentable(hex: 0x3B4252, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x323846),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x81A1C1),
            string: ColorRepresentable(hex: 0xA3BE8C),
            number: ColorRepresentable(hex: 0xB48EAD),
            comment: ColorRepresentable(hex: 0x616E88),
            plain: ColorRepresentable(hex: 0xD8DEE9),
            function: ColorRepresentable(hex: 0x8FBCBB),
            operatorSymbol: ColorRepresentable(hex: 0xBF616A),
            identifier: ColorRepresentable(hex: 0xEBCB8B)
        )
    )
}
