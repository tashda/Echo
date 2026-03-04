import SwiftUI

struct SQLEditorPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    enum Tone: String, Codable, CaseIterable {
        case light
        case dark
    }

    struct TokenStyle: Codable, Equatable, Hashable {
        var color: ColorRepresentable
        var isBold: Bool
        var isItalic: Bool

        init(color: ColorRepresentable, isBold: Bool = false, isItalic: Bool = false) {
            self.color = color
            self.isBold = isBold
            self.isItalic = isItalic
        }

        init(from decoder: Decoder) throws {
            if let single = try? decoder.singleValueContainer(),
               let color = try? single.decode(ColorRepresentable.self) {
                self.init(color: color)
                return
            }

            let container = try decoder.container(keyedBy: CodingKeys.self)
            let color = try container.decode(ColorRepresentable.self, forKey: .color)
            let isBold = try container.decodeIfPresent(Bool.self, forKey: .isBold) ?? false
            let isItalic = try container.decodeIfPresent(Bool.self, forKey: .isItalic) ?? false
            self.init(color: color, isBold: isBold, isItalic: isItalic)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(color, forKey: .color)
            if isBold {
                try container.encode(isBold, forKey: .isBold)
            }
            if isItalic {
                try container.encode(isItalic, forKey: .isItalic)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case color
            case isBold
            case isItalic
        }

        var swiftColor: Color { color.color }

#if os(macOS)
        var nsColor: NSColor { color.nsColor }
#else
        var uiColor: UIColor { color.uiColor }
#endif

        func platformFont(from base: PlatformFont) -> PlatformFont {
#if os(macOS)
            var traits: NSFontTraitMask = []
            if isBold {
                traits.insert(.boldFontMask)
            }
            if isItalic {
                traits.insert(.italicFontMask)
            }
            guard !traits.isEmpty else { return base }
            return NSFontManager.shared.convert(base, toHaveTrait: traits)
#else
            var traits = base.fontDescriptor.symbolicTraits
            if isBold {
                traits.insert(.traitBold)
            }
            if isItalic {
                traits.insert(.traitItalic)
            }
            guard let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else {
                return base
            }
            return UIFont(descriptor: descriptor, size: base.pointSize)
#endif
        }

        func swiftUIFont(from base: PlatformFont) -> Font {
#if os(macOS)
            Font(platformFont(from: base))
#else
            Font(platformFont(from: base))
#endif
        }
    }

    struct TokenColors: Codable, Equatable, Hashable {
        var keyword: TokenStyle
        var string: TokenStyle
        var number: TokenStyle
        var comment: TokenStyle
        var plain: TokenStyle
        var function: TokenStyle
        var operatorSymbol: TokenStyle
        var identifier: TokenStyle

        private enum CodingKeys: String, CodingKey {
            case keyword
            case primaryKeyword
            case secondaryKeyword
            case string
            case number
            case comment
            case plain
            case function
            case operatorSymbol
            case identifier
        }

        init(
            keyword: TokenStyle,
            string: TokenStyle,
            number: TokenStyle,
            comment: TokenStyle,
            plain: TokenStyle,
            function: TokenStyle,
            operatorSymbol: TokenStyle,
            identifier: TokenStyle
        ) {
            self.keyword = keyword
            self.string = string
            self.number = number
            self.comment = comment
            self.plain = plain
            self.function = function
            self.operatorSymbol = operatorSymbol
            self.identifier = identifier
        }

        init(
            keyword: ColorRepresentable,
            string: ColorRepresentable,
            number: ColorRepresentable,
            comment: ColorRepresentable,
            plain: ColorRepresentable,
            function: ColorRepresentable,
            operatorSymbol: ColorRepresentable,
            identifier: ColorRepresentable
        ) {
            self.init(
                keyword: TokenStyle(color: keyword, isBold: true),
                string: TokenStyle(color: string),
                number: TokenStyle(color: number),
                comment: TokenStyle(color: comment),
                plain: TokenStyle(color: plain),
                function: TokenStyle(color: function),
                operatorSymbol: TokenStyle(color: operatorSymbol),
                identifier: TokenStyle(color: identifier)
            )
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let explicit = try container.decodeIfPresent(TokenStyle.self, forKey: .keyword) {
                keyword = explicit
            } else if let legacyPrimary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .primaryKeyword) {
                keyword = TokenStyle(color: legacyPrimary, isBold: true)
            } else if let legacySecondary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .secondaryKeyword) {
                keyword = TokenStyle(color: legacySecondary, isBold: true)
            } else {
                keyword = TokenStyle(color: ColorRepresentable(hex: 0x3367D6), isBold: true)
            }

            string = try container.decode(TokenStyle.self, forKey: .string)
            number = try container.decode(TokenStyle.self, forKey: .number)
            comment = try container.decode(TokenStyle.self, forKey: .comment)
            plain = try container.decode(TokenStyle.self, forKey: .plain)
            function = try container.decode(TokenStyle.self, forKey: .function)
            operatorSymbol = try container.decode(TokenStyle.self, forKey: .operatorSymbol)
            identifier = try container.decode(TokenStyle.self, forKey: .identifier)
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(keyword, forKey: .keyword)
            try container.encode(string, forKey: .string)
            try container.encode(number, forKey: .number)
            try container.encode(comment, forKey: .comment)
            try container.encode(plain, forKey: .plain)
            try container.encode(function, forKey: .function)
            try container.encode(operatorSymbol, forKey: .operatorSymbol)
            try container.encode(identifier, forKey: .identifier)
        }
    }

    var id: String
    var name: String
    var kind: Kind
    var isDark: Bool
    var background: ColorRepresentable
    var text: ColorRepresentable
    var gutterBackground: ColorRepresentable
    var gutterText: ColorRepresentable
    var gutterAccent: ColorRepresentable
    var selection: ColorRepresentable
    var currentLine: ColorRepresentable
    var tokens: TokenColors

    init(
        id: String,
        name: String,
        kind: Kind,
        isDark: Bool,
        background: ColorRepresentable,
        text: ColorRepresentable,
        gutterBackground: ColorRepresentable,
        gutterText: ColorRepresentable,
        gutterAccent: ColorRepresentable,
        selection: ColorRepresentable,
        currentLine: ColorRepresentable,
        tokens: TokenColors
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isDark = isDark
        self.background = background
        self.text = text
        self.gutterBackground = gutterBackground
        self.gutterText = gutterText
        self.gutterAccent = gutterAccent
        self.selection = selection
        self.currentLine = currentLine
        self.tokens = tokens
    }
}

extension SQLEditorPalette.TokenStyle {
    init(color: Color, isBold: Bool = false, isItalic: Bool = false) {
        self.init(color: ColorRepresentable(color: color), isBold: isBold, isItalic: isItalic)
    }

    func withColor(_ color: Color) -> SQLEditorPalette.TokenStyle {
        SQLEditorPalette.TokenStyle(color: ColorRepresentable(color: color), isBold: isBold, isItalic: isItalic)
    }
}

extension SQLEditorPalette {
    var tone: Tone { isDark ? .dark : .light }

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

    static let builtIn: [SQLEditorPalette] = [
        echoLight,
        aurora,
        solstice,
        githubLight,
        catppuccinLatte,
        emberLight,
        seaBreeze,
        orchard,
        paperwhite,
        echoDark,
        midnight,
        oneDark,
        dracula,
        nord,
        nebulaNight,
        emberDark,
        charcoal,
        catppuccinMocha,
        solarizedDark,
        violetStorm
    ]

    static func palette(withID id: String) -> SQLEditorPalette? {
        builtIn.first { $0.id == id }
    }
}

extension SQLEditorPalette {
    var backgroundColor: Color { background.color }
    var textColor: Color { text.color }
    var gutterBackgroundColor: Color { gutterBackground.color }
    var gutterTextColor: Color { gutterText.color }
    var gutterAccentColor: Color { gutterAccent.color }
    var selectionColor: Color { selection.color }
    var currentLineColor: Color { currentLine.color }

    func asCustomCopy(named name: String? = nil) -> SQLEditorPalette {
        SQLEditorPalette(
            id: "custom-" + UUID().uuidString,
            name: name ?? "\(self.name) Copy",
            kind: .custom,
            isDark: isDark,
            background: background,
            text: text,
            gutterBackground: gutterBackground,
            gutterText: gutterText,
            gutterAccent: gutterAccent,
            selection: selection,
            currentLine: currentLine,
            tokens: tokens
        )
    }
}
