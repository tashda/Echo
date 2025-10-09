import SwiftUI
import CoreGraphics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SQLEditorSurfaceColors: Codable, Equatable {
    var background: ColorRepresentable
    var text: ColorRepresentable
    var gutterBackground: ColorRepresentable
    var gutterText: ColorRepresentable
    var gutterAccent: ColorRepresentable
    var selection: ColorRepresentable
    var currentLine: ColorRepresentable
    var symbolHighlightStrong: ColorRepresentable?
    var symbolHighlightBright: ColorRepresentable?
}

struct SQLEditorTheme: Codable, Equatable {
    static let defaultFontName = "JetBrainsMono-Regular"
    static let defaultFontSize: CGFloat = 12
    static let defaultLineHeight: CGFloat = 1.0

    var fontName: String
    var fontSize: CGFloat
    var lineHeightMultiplier: CGFloat
    var surfaces: SQLEditorSurfaceColors
    var tokenPalette: SQLEditorTokenPalette
    var palette: SQLEditorTokenPalette { tokenPalette }

    init(
        fontName: String = SQLEditorTheme.defaultFontName,
        fontSize: CGFloat = SQLEditorTheme.defaultFontSize,
        lineHeightMultiplier: CGFloat = SQLEditorTheme.defaultLineHeight,
        surfaces: SQLEditorSurfaceColors,
        tokenPalette: SQLEditorTokenPalette
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeightMultiplier = lineHeightMultiplier
        self.surfaces = surfaces
        self.tokenPalette = tokenPalette
    }

    var tone: SQLEditorPalette.Tone { tokenPalette.tone }

    var tokenColors: SQLEditorPalette.TokenColors { tokenPalette.tokens }

    var font: NSFontWithFallback {
        NSFontWithFallback(name: fontName, size: fontSize)
    }

#if os(macOS)
    var nsFont: NSFont { font.font }
#else
    var uiFont: UIFont { font.font }
#endif

    static func fallback(tone: SQLEditorPalette.Tone = .light) -> SQLEditorTheme {
        let baseTheme = AppColorTheme.builtInThemes(for: tone).first
            ?? AppColorTheme.fromPalette(tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)

        let palette = SQLEditorTokenPalette.builtIn.first(where: { $0.id == baseTheme.defaultPaletteID })
            ?? SQLEditorTokenPalette.builtIn.first(where: { $0.tone == tone })
            ?? SQLEditorTokenPalette(from: tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)

        let strongHighlight = baseTheme.editorSymbolHighlightStrong
            ?? SQLEditorTokenPalette.defaultSymbolHighlightStrong(
                selection: baseTheme.editorSelection,
                accent: baseTheme.accent,
                background: baseTheme.editorBackground,
                isDark: tone == .dark
            )
        let brightHighlight = baseTheme.editorSymbolHighlightBright
            ?? SQLEditorTokenPalette.defaultSymbolHighlightBright(
                selection: baseTheme.editorSelection,
                accent: baseTheme.accent,
                background: baseTheme.editorBackground,
                isDark: tone == .dark
            )

        let surfaces = SQLEditorSurfaceColors(
            background: baseTheme.editorBackground,
            text: baseTheme.editorForeground,
            gutterBackground: baseTheme.editorGutterBackground,
            gutterText: baseTheme.editorGutterForeground,
            gutterAccent: baseTheme.accent ?? baseTheme.editorForeground,
            selection: baseTheme.editorSelection,
            currentLine: baseTheme.editorCurrentLine,
            symbolHighlightStrong: strongHighlight,
            symbolHighlightBright: brightHighlight
        )

        return SQLEditorTheme(
            surfaces: surfaces,
            tokenPalette: palette
        )
    }
}

struct SQLEditorDisplayOptions: Codable, Equatable {
    var showLineNumbers: Bool
    var highlightSelectedSymbol: Bool
    var highlightDelay: Double
    var wrapLines: Bool
    var indentWrappedLines: Int
    var autoCompletionEnabled: Bool
    var suggestTableAliasesInCompletion: Bool

    init(
        showLineNumbers: Bool = true,
        highlightSelectedSymbol: Bool = true,
        highlightDelay: Double = 0.25,
        wrapLines: Bool = true,
        indentWrappedLines: Int = 4,
        autoCompletionEnabled: Bool = true,
        suggestTableAliasesInCompletion: Bool = false
    ) {
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedSymbol = highlightSelectedSymbol
        self.highlightDelay = highlightDelay
        self.wrapLines = wrapLines
        self.indentWrappedLines = indentWrappedLines
        self.autoCompletionEnabled = autoCompletionEnabled
        self.suggestTableAliasesInCompletion = suggestTableAliasesInCompletion
    }

    private enum CodingKeys: String, CodingKey {
        case showLineNumbers
        case highlightSelectedSymbol
        case highlightDelay
        case wrapLines
        case indentWrappedLines
        case autoCompletionEnabled
        case suggestTableAliasesInCompletion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        showLineNumbers = try container.decode(Bool.self, forKey: .showLineNumbers)
        highlightSelectedSymbol = try container.decode(Bool.self, forKey: .highlightSelectedSymbol)
        highlightDelay = try container.decode(Double.self, forKey: .highlightDelay)
        wrapLines = try container.decode(Bool.self, forKey: .wrapLines)
        indentWrappedLines = try container.decode(Int.self, forKey: .indentWrappedLines)
        autoCompletionEnabled = try container.decode(Bool.self, forKey: .autoCompletionEnabled)
        suggestTableAliasesInCompletion = try container.decodeIfPresent(Bool.self, forKey: .suggestTableAliasesInCompletion) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(showLineNumbers, forKey: .showLineNumbers)
        try container.encode(highlightSelectedSymbol, forKey: .highlightSelectedSymbol)
        try container.encode(highlightDelay, forKey: .highlightDelay)
        try container.encode(wrapLines, forKey: .wrapLines)
        try container.encode(indentWrappedLines, forKey: .indentWrappedLines)
        try container.encode(autoCompletionEnabled, forKey: .autoCompletionEnabled)
        try container.encode(suggestTableAliasesInCompletion, forKey: .suggestTableAliasesInCompletion)
    }
}

struct SQLEditorTokenPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    var id: String
    var name: String
    var kind: Kind
    var tone: SQLEditorPalette.Tone
    var tokens: SQLEditorPalette.TokenColors

    init(
        id: String,
        name: String,
        kind: Kind,
        tone: SQLEditorPalette.Tone,
        tokens: SQLEditorPalette.TokenColors
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.tone = tone
        self.tokens = tokens
    }

    init(from palette: SQLEditorPalette) {
        self.init(
            id: palette.id,
            name: palette.name,
            kind: palette.kind == .custom ? .custom : .builtIn,
            tone: palette.tone,
            tokens: palette.tokens
        )
    }

    func asCustomCopy(named name: String? = nil) -> SQLEditorTokenPalette {
        SQLEditorTokenPalette(
            id: "custom-\(UUID().uuidString)",
            name: name ?? "\(self.name) Copy",
            kind: .custom,
            tone: tone,
            tokens: tokens
        )
    }

    static let builtIn: [SQLEditorTokenPalette] = SQLEditorPalette.builtIn.map { SQLEditorTokenPalette(from: $0) }

    static func palette(withID id: String, customPalettes: [SQLEditorTokenPalette] = []) -> SQLEditorTokenPalette? {
        if let custom = customPalettes.first(where: { $0.id == id }) {
            return custom
        }
        return builtIn.first(where: { $0.id == id })
    }

    static func defaultSymbolHighlightStrong(
        selection: ColorRepresentable,
        accent: ColorRepresentable?,
        background: ColorRepresentable,
        isDark: Bool
    ) -> ColorRepresentable {
        let base = accent ?? selection
        let blend = isDark ? 0.24 : 0.32
        let alpha = isDark ? 0.48 : 0.42
        let tinted = base.blended(with: background, fraction: blend)
        return tinted.withAlpha(alpha)
    }

    static func defaultSymbolHighlightBright(
        selection: ColorRepresentable,
        accent: ColorRepresentable?,
        background: ColorRepresentable,
        isDark: Bool
    ) -> ColorRepresentable {
        let base = accent ?? selection
        let blend = isDark ? 0.55 : 0.68
        let alpha = isDark ? 0.3 : 0.26
        let tinted = base.blended(with: background, fraction: blend)
        return tinted.withAlpha(alpha)
    }
}

extension SQLEditorTokenPalette {
    var showcaseColors: [Color] {
        [
            tokens.keyword.color,
            tokens.string.color,
            tokens.operatorSymbol.color,
            tokens.identifier.color,
            tokens.comment.color
        ]
    }
}

struct SQLEditorPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    enum Tone: String, Codable, CaseIterable {
        case light
        case dark
    }

    struct TokenColors: Codable, Equatable, Hashable {
        var keyword: ColorRepresentable
        var string: ColorRepresentable
        var number: ColorRepresentable
        var comment: ColorRepresentable
        var plain: ColorRepresentable
        var function: ColorRepresentable
        var operatorSymbol: ColorRepresentable
        var identifier: ColorRepresentable

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
            keyword: ColorRepresentable,
            string: ColorRepresentable,
            number: ColorRepresentable,
            comment: ColorRepresentable,
            plain: ColorRepresentable,
            function: ColorRepresentable,
            operatorSymbol: ColorRepresentable,
            identifier: ColorRepresentable
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

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let explicit = try container.decodeIfPresent(ColorRepresentable.self, forKey: .keyword) {
                keyword = explicit
            } else if let legacyPrimary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .primaryKeyword) {
                keyword = legacyPrimary
            } else if let legacySecondary = try container.decodeIfPresent(ColorRepresentable.self, forKey: .secondaryKeyword) {
                keyword = legacySecondary
            } else {
                keyword = ColorRepresentable(hex: 0x3367D6)
            }

            string = try container.decode(ColorRepresentable.self, forKey: .string)
            number = try container.decode(ColorRepresentable.self, forKey: .number)
            comment = try container.decode(ColorRepresentable.self, forKey: .comment)
            plain = try container.decode(ColorRepresentable.self, forKey: .plain)
            function = try container.decode(ColorRepresentable.self, forKey: .function)
            operatorSymbol = try container.decode(ColorRepresentable.self, forKey: .operatorSymbol)
            identifier = try container.decode(ColorRepresentable.self, forKey: .identifier)
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

extension SQLEditorPalette {
    var tone: Tone { isDark ? .dark : .light }

    static let aurora = SQLEditorPalette(
        id: "aurora",
        name: "Aurora",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFFFFFF),
        text: ColorRepresentable(hex: 0x1C2434),
        gutterBackground: ColorRepresentable(hex: 0xF2F4F8),
        gutterText: ColorRepresentable(hex: 0x7B8798),
        gutterAccent: ColorRepresentable(hex: 0xC8D2E4),
        selection: ColorRepresentable(hex: 0xD8E7FF, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xEEF4FF),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x3367D6),
            string: ColorRepresentable(hex: 0x0C9A6F),
            number: ColorRepresentable(hex: 0xB25D07),
            comment: ColorRepresentable(hex: 0x94A3B8),
            plain: ColorRepresentable(hex: 0x1C2434),
            function: ColorRepresentable(hex: 0xC44191),
            operatorSymbol: ColorRepresentable(hex: 0xAF3041),
            identifier: ColorRepresentable(hex: 0x24314A)
        )
    )

    static let midnight = SQLEditorPalette(
        id: "midnight",
        name: "Midnight",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x0B1220),
        text: ColorRepresentable(hex: 0xE5E9F0),
        gutterBackground: ColorRepresentable(hex: 0x121C2F),
        gutterText: ColorRepresentable(hex: 0x5B6A83),
        gutterAccent: ColorRepresentable(hex: 0x1F2A3D),
        selection: ColorRepresentable(hex: 0x1F3A5C, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x16233A),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x7DD3FC),
            string: ColorRepresentable(hex: 0x34D399),
            number: ColorRepresentable(hex: 0xF87171),
            comment: ColorRepresentable(hex: 0x6B7280),
            plain: ColorRepresentable(hex: 0xE5E9F0),
            function: ColorRepresentable(hex: 0xC084FC),
            operatorSymbol: ColorRepresentable(hex: 0xF97316),
            identifier: ColorRepresentable(hex: 0xA5B4FC)
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
        background: ColorRepresentable(hex: 0xFBFDF7),
        text: ColorRepresentable(hex: 0x2F3A1F),
        gutterBackground: ColorRepresentable(hex: 0xE7F0E0),
        gutterText: ColorRepresentable(hex: 0x6E8163),
        gutterAccent: ColorRepresentable(hex: 0xC4D7B5),
        selection: ColorRepresentable(hex: 0xDCEFD0, alpha: 0.85),
        currentLine: ColorRepresentable(hex: 0xEEF6E4),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x5A8C2D),
            string: ColorRepresentable(hex: 0xB3682D),
            number: ColorRepresentable(hex: 0xD19C27),
            comment: ColorRepresentable(hex: 0x94A281),
            plain: ColorRepresentable(hex: 0x2F3A1F),
            function: ColorRepresentable(hex: 0x4A7FB6),
            operatorSymbol: ColorRepresentable(hex: 0xBF4F56),
            identifier: ColorRepresentable(hex: 0x3A5C2D)
        )
    )

    static let paperwhite = SQLEditorPalette(
        id: "paperwhite",
        name: "Paperwhite",
        kind: .builtIn,
        isDark: false,
        background: ColorRepresentable(hex: 0xFAFAF5),
        text: ColorRepresentable(hex: 0x2C2F3C),
        gutterBackground: ColorRepresentable(hex: 0xECEDE5),
        gutterText: ColorRepresentable(hex: 0x7A7F8C),
        gutterAccent: ColorRepresentable(hex: 0xC7C9BE),
        selection: ColorRepresentable(hex: 0xD7DEF6, alpha: 0.82),
        currentLine: ColorRepresentable(hex: 0xEEEFE8),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x2948B2),
            string: ColorRepresentable(hex: 0x1F7F5F),
            number: ColorRepresentable(hex: 0xB25C3B),
            comment: ColorRepresentable(hex: 0xA0A3AD),
            plain: ColorRepresentable(hex: 0x2C2F3C),
            function: ColorRepresentable(hex: 0x6C4FB2),
            operatorSymbol: ColorRepresentable(hex: 0xB23745),
            identifier: ColorRepresentable(hex: 0x44506B)
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
        background: ColorRepresentable(hex: 0x1B0F12),
        text: ColorRepresentable(hex: 0xF5E6E1),
        gutterBackground: ColorRepresentable(hex: 0x241517),
        gutterText: ColorRepresentable(hex: 0x8B5F61),
        gutterAccent: ColorRepresentable(hex: 0x3A1E22),
        selection: ColorRepresentable(hex: 0x3E1C27, alpha: 0.9),
        currentLine: ColorRepresentable(hex: 0x2A161B),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0xF27C5B),
            string: ColorRepresentable(hex: 0xF2C879),
            number: ColorRepresentable(hex: 0xF59F5A),
            comment: ColorRepresentable(hex: 0xA77679),
            plain: ColorRepresentable(hex: 0xF5E6E1),
            function: ColorRepresentable(hex: 0xFF87B7),
            operatorSymbol: ColorRepresentable(hex: 0xF25A7A),
            identifier: ColorRepresentable(hex: 0xF0B27A)
        )
    )

    static let charcoal = SQLEditorPalette(
        id: "charcoal",
        name: "Charcoal",
        kind: .builtIn,
        isDark: true,
        background: ColorRepresentable(hex: 0x111418),
        text: ColorRepresentable(hex: 0xD8DEE6),
        gutterBackground: ColorRepresentable(hex: 0x161B21),
        gutterText: ColorRepresentable(hex: 0x5A636E),
        gutterAccent: ColorRepresentable(hex: 0x222831),
        selection: ColorRepresentable(hex: 0x1F2A37, alpha: 0.92),
        currentLine: ColorRepresentable(hex: 0x1A232D),
        tokens: .init(
            keyword: ColorRepresentable(hex: 0x5DA9F6),
            string: ColorRepresentable(hex: 0x4BD0A0),
            number: ColorRepresentable(hex: 0xF2A65A),
            comment: ColorRepresentable(hex: 0x6E7A88),
            plain: ColorRepresentable(hex: 0xD8DEE6),
            function: ColorRepresentable(hex: 0x7D8CFF),
            operatorSymbol: ColorRepresentable(hex: 0xF5546B),
            identifier: ColorRepresentable(hex: 0x8AD1FF)
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

    static let builtIn: [SQLEditorPalette] = [
        aurora,
        solstice,
        githubLight,
        catppuccinLatte,
        emberLight,
        seaBreeze,
        orchard,
        paperwhite,
        midnight,
        oneDark,
        dracula,
        nord,
        nebulaNight,
        emberDark,
        charcoal,
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

struct NSFontWithFallback {
    var name: String
    var size: CGFloat

    init(name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

#if os(macOS)
    var font: NSFont {
        if let custom = NSFont(name: name, size: size) {
            return custom
        }
        if let familyFont = NSFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return familyFont
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#else
    var font: UIFont {
        if let custom = UIFont(name: name, size: size) {
            return custom
        }
        if let familyFont = UIFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return familyFont
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#endif
}

enum SQLEditorThemeResolver {
    static func resolve(globalSettings: GlobalSettings, project: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTheme {
        let applicationTheme = resolveApplicationTheme(globalSettings: globalSettings, tone: tone)
        let tokenPalette = resolveTokenPalette(globalSettings: globalSettings, project: project, tone: tone)

        let projectFontName = sanitizedFontName(project?.settings.editorFontFamily)
        let globalFontName = sanitizedFontName(globalSettings.defaultEditorFontFamily)
        let fontName = projectFontName ?? globalFontName ?? SQLEditorTheme.defaultFontName
        let fontSizeValue = project?.settings.editorFontSize ?? globalSettings.defaultEditorFontSize
        let lineHeightValue = project?.settings.editorLineHeight ?? globalSettings.defaultEditorLineHeight

        let fontSize = max(8, CGFloat(fontSizeValue))
        let lineHeight = max(1.0, CGFloat(lineHeightValue))

        let strongHighlight = applicationTheme.editorSymbolHighlightStrong
            ?? SQLEditorTokenPalette.defaultSymbolHighlightStrong(
                selection: applicationTheme.editorSelection,
                accent: applicationTheme.accent,
                background: applicationTheme.editorBackground,
                isDark: tone == .dark
            )
        let brightHighlight = applicationTheme.editorSymbolHighlightBright
            ?? SQLEditorTokenPalette.defaultSymbolHighlightBright(
                selection: applicationTheme.editorSelection,
                accent: applicationTheme.accent,
                background: applicationTheme.editorBackground,
                isDark: tone == .dark
            )

        let surfaces = SQLEditorSurfaceColors(
            background: applicationTheme.editorBackground,
            text: applicationTheme.editorForeground,
            gutterBackground: applicationTheme.editorGutterBackground,
            gutterText: applicationTheme.editorGutterForeground,
            gutterAccent: applicationTheme.accent ?? applicationTheme.editorForeground,
            selection: applicationTheme.editorSelection,
            currentLine: applicationTheme.editorCurrentLine,
            symbolHighlightStrong: strongHighlight,
            symbolHighlightBright: brightHighlight
        )

        return SQLEditorTheme(
            fontName: fontName,
            fontSize: fontSize,
            lineHeightMultiplier: lineHeight,
            surfaces: surfaces,
            tokenPalette: tokenPalette
        )
    }

    static func resolveDisplayOptions(globalSettings: GlobalSettings, project: Project?) -> SQLEditorDisplayOptions {
        let showLineNumbers = project?.settings.showLineNumbers ?? globalSettings.editorShowLineNumbers
        let highlightSelected = project?.settings.highlightSelectedSymbol ?? globalSettings.editorHighlightSelectedSymbol
        let highlightDelay = clamped(project?.settings.highlightDelay ?? globalSettings.editorHighlightDelay, min: 0.0, max: 5.0)
        let wrapLines = project?.settings.wrapLines ?? globalSettings.editorWrapLines
        let indentWrappedLines = max(0, project?.settings.indentWrappedLines ?? globalSettings.editorIndentWrappedLines)
        let autoCompletionEnabled = project?.settings.enableAutocomplete ?? globalSettings.editorEnableAutocomplete

        return SQLEditorDisplayOptions(
            showLineNumbers: showLineNumbers,
            highlightSelectedSymbol: highlightSelected,
            highlightDelay: highlightDelay,
            wrapLines: wrapLines,
            indentWrappedLines: indentWrappedLines,
            autoCompletionEnabled: autoCompletionEnabled
        )
    }

    private static func resolveApplicationTheme(globalSettings: GlobalSettings, tone: SQLEditorPalette.Tone) -> AppColorTheme {
        if let themeID = globalSettings.activeThemeID(for: tone),
           let theme = globalSettings.theme(withID: themeID, tone: tone) {
            return theme
        }

        if let fallback = AppColorTheme.builtInThemes(for: tone).first {
            return fallback
        }

        return AppColorTheme.fromPalette(tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)
    }

    private static func resolveTokenPalette(globalSettings: GlobalSettings, project: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette {
        if let projectPalette = project?.settings.customEditorPalette {
            return projectPalette
        }

        if let paletteID = project?.settings.effectivePaletteIdentifier,
           let palette = palette(withID: paletteID, globalSettings: globalSettings, project: project) {
            return palette
        }

        if let palette = globalSettings.defaultPalette(for: tone) {
            return palette
        }

        let alternateTone: SQLEditorPalette.Tone = tone == .light ? .dark : .light
        if let palette = globalSettings.defaultPalette(for: alternateTone) {
            return palette
        }

        if let legacy = palette(withID: globalSettings.defaultEditorTheme, globalSettings: globalSettings, project: project) {
            return legacy
        }

        let fallback = tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
        return SQLEditorTokenPalette(from: fallback)
    }

    private static func sanitizedFontName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func palette(withID id: String, globalSettings: GlobalSettings, project: Project?) -> SQLEditorTokenPalette? {
        if let projectPalette = project?.settings.customEditorPalette, projectPalette.id == id {
            return projectPalette
        }

        if let custom = globalSettings.customEditorPalettes.first(where: { $0.id == id }) {
            return custom
        }

        return SQLEditorTokenPalette.builtIn.first(where: { $0.id == id })
    }

    private static func clamped(_ value: Double, min: Double, max: Double) -> Double {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
