import SwiftUI
import CoreGraphics
import CoreText

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
    static let systemFontIdentifier = "__system_monospaced__"
    static let defaultFontSize: CGFloat = 12
    static let defaultLineHeight: CGFloat = 1.0

    var fontName: String
    var fontSize: CGFloat
    var lineHeightMultiplier: CGFloat
    var ligaturesEnabled: Bool = true
    var surfaces: SQLEditorSurfaceColors
    var tokenPalette: SQLEditorTokenPalette
    var palette: SQLEditorTokenPalette { tokenPalette }

    init(
        fontName: String = SQLEditorTheme.defaultFontName,
        fontSize: CGFloat = SQLEditorTheme.defaultFontSize,
        lineHeightMultiplier: CGFloat = SQLEditorTheme.defaultLineHeight,
        ligaturesEnabled: Bool = true,
        surfaces: SQLEditorSurfaceColors,
        tokenPalette: SQLEditorTokenPalette
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeightMultiplier = lineHeightMultiplier
        self.ligaturesEnabled = ligaturesEnabled
        self.surfaces = surfaces
        self.tokenPalette = tokenPalette
    }

    enum CodingKeys: String, CodingKey {
        case fontName
        case fontSize
        case lineHeightMultiplier
        case ligaturesEnabled
        case surfaces
        case tokenPalette
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fontName = try container.decode(String.self, forKey: .fontName)
        fontSize = try container.decode(CGFloat.self, forKey: .fontSize)
        lineHeightMultiplier = try container.decode(CGFloat.self, forKey: .lineHeightMultiplier)
        ligaturesEnabled = try container.decodeIfPresent(Bool.self, forKey: .ligaturesEnabled) ?? true
        surfaces = try container.decode(SQLEditorSurfaceColors.self, forKey: .surfaces)
        tokenPalette = try container.decode(SQLEditorTokenPalette.self, forKey: .tokenPalette)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fontName, forKey: .fontName)
        try container.encode(fontSize, forKey: .fontSize)
        try container.encode(lineHeightMultiplier, forKey: .lineHeightMultiplier)
        try container.encode(ligaturesEnabled, forKey: .ligaturesEnabled)
        try container.encode(surfaces, forKey: .surfaces)
        try container.encode(tokenPalette, forKey: .tokenPalette)
    }

    var tone: SQLEditorPalette.Tone { tokenPalette.tone }

    var tokenColors: SQLEditorPalette.TokenColors { tokenPalette.tokens }

    var font: NSFontWithFallback {
        NSFontWithFallback(name: fontName, size: fontSize, ligaturesEnabled: ligaturesEnabled)
    }

    static func isSystemFontIdentifier(_ value: String) -> Bool {
        value == systemFontIdentifier
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

    struct ResultGridStyle: Codable, Equatable, Hashable {
        var color: ColorRepresentable
        var isBold: Bool
        var isItalic: Bool

        init(color: ColorRepresentable, isBold: Bool = false, isItalic: Bool = false) {
            self.color = color
            self.isBold = isBold
            self.isItalic = isItalic
        }

        var swiftColor: Color { color.color }

#if os(macOS)
        var nsColor: NSColor { color.nsColor }
#elseif canImport(UIKit)
        var uiColor: UIColor { color.uiColor }
#endif
    }

    struct ResultGridColors: Codable, Equatable, Hashable {
        var null: ResultGridStyle
        var numeric: ResultGridStyle
        var boolean: ResultGridStyle
        var temporal: ResultGridStyle
        var binary: ResultGridStyle
        var identifier: ResultGridStyle
        var json: ResultGridStyle

        static func defaults(for tone: SQLEditorPalette.Tone) -> ResultGridColors {
            switch tone {
            case .light:
                return ResultGridColors(
                    null: ResultGridStyle(color: ColorRepresentable(hex: 0x6B7280, alpha: 0.7), isItalic: true),
                    numeric: ResultGridStyle(color: ColorRepresentable(hex: 0x1D4ED8)),
                    boolean: ResultGridStyle(color: ColorRepresentable(hex: 0x047857)),
                    temporal: ResultGridStyle(color: ColorRepresentable(hex: 0xB45309)),
                    binary: ResultGridStyle(color: ColorRepresentable(hex: 0x7C3AED)),
                    identifier: ResultGridStyle(color: ColorRepresentable(hex: 0x4338CA)),
                    json: ResultGridStyle(color: ColorRepresentable(hex: 0x0F766E))
                )
            case .dark:
                return ResultGridColors(
                    null: ResultGridStyle(color: ColorRepresentable(hex: 0xCBD5F5, alpha: 0.85), isItalic: true),
                    numeric: ResultGridStyle(color: ColorRepresentable(hex: 0x60A5FA)),
                    boolean: ResultGridStyle(color: ColorRepresentable(hex: 0x34D399)),
                    temporal: ResultGridStyle(color: ColorRepresentable(hex: 0xFBBF24)),
                    binary: ResultGridStyle(color: ColorRepresentable(hex: 0xC084FC)),
                    identifier: ResultGridStyle(color: ColorRepresentable(hex: 0xA5B4FF)),
                    json: ResultGridStyle(color: ColorRepresentable(hex: 0x5EEAD4))
                )
            }
        }
    }

    var id: String
    var name: String
    var kind: Kind
    var tone: SQLEditorPalette.Tone
    var tokens: SQLEditorPalette.TokenColors
    var resultGrid: ResultGridColors

    init(
        id: String,
        name: String,
        kind: Kind,
        tone: SQLEditorPalette.Tone,
        tokens: SQLEditorPalette.TokenColors,
        resultGrid: ResultGridColors? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.tone = tone
        self.tokens = tokens
        self.resultGrid = resultGrid ?? ResultGridColors.defaults(for: tone)
    }

    init(from palette: SQLEditorPalette) {
        self.init(
            id: palette.id,
            name: palette.name,
            kind: palette.kind == .custom ? .custom : .builtIn,
            tone: palette.tone,
            tokens: palette.tokens,
            resultGrid: ResultGridColors.defaults(for: palette.tone)
        )
    }

    func asCustomCopy(named name: String? = nil) -> SQLEditorTokenPalette {
        SQLEditorTokenPalette(
            id: "custom-\(UUID().uuidString)",
            name: name ?? "\(self.name) Copy",
            kind: .custom,
            tone: tone,
            tokens: tokens,
            resultGrid: resultGrid
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case tone
        case tokens
        case resultGrid
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(Kind.self, forKey: .kind)
        tone = try container.decode(SQLEditorPalette.Tone.self, forKey: .tone)
        tokens = try container.decode(SQLEditorPalette.TokenColors.self, forKey: .tokens)
        resultGrid = try container.decodeIfPresent(ResultGridColors.self, forKey: .resultGrid)
            ?? ResultGridColors.defaults(for: tone)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(tone, forKey: .tone)
        try container.encode(tokens, forKey: .tokens)
        try container.encode(resultGrid, forKey: .resultGrid)
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
            tokens.keyword.swiftColor,
            tokens.string.swiftColor,
            tokens.operatorSymbol.swiftColor,
            tokens.identifier.swiftColor,
            tokens.comment.swiftColor
        ]
    }

    func style(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        switch kind {
        case .null:
            return resultGrid.null
        case .numeric:
            return resultGrid.numeric
        case .boolean:
            return resultGrid.boolean
        case .temporal:
            return resultGrid.temporal
        case .binary:
            return resultGrid.binary
        case .identifier:
            return resultGrid.identifier
        case .json:
            return resultGrid.json
        case .text:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .labelColor)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .label)))
#endif
        }
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
    var ligaturesEnabled: Bool

    init(name: String, size: CGFloat, ligaturesEnabled: Bool = true) {
        self.name = name
        self.size = size
        self.ligaturesEnabled = ligaturesEnabled
    }

#if os(macOS)
    var font: NSFont {
        if SQLEditorTheme.isSystemFontIdentifier(name) {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let custom = NSFont(name: name, size: size) {
            return custom
        }
        if let fallback = NSFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return fallback
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#else
    var font: UIFont {
        if SQLEditorTheme.isSystemFontIdentifier(name) {
            return .monospacedSystemFont(ofSize: size, weight: .regular)
        }
        if let custom = UIFont(name: name, size: size) {
            return custom
        }
        if let fallback = UIFont(name: SQLEditorTheme.defaultFontName, size: size) {
            return fallback
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
#endif
}

enum SQLEditorThemeResolver {
    static func resolve(globalSettings: GlobalSettings, project: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTheme {
        FontRegistrar.registerBundledFonts()

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
            ligaturesEnabled: globalSettings.ligaturesEnabled(for: fontName),
            surfaces: surfaces,
            tokenPalette: tokenPalette
        )
    }

    static func resolveDisplayOptions(globalSettings: GlobalSettings, project _: Project?) -> SQLEditorDisplayOptions {
        SQLEditorDisplayOptions(
            showLineNumbers: globalSettings.editorShowLineNumbers,
            highlightSelectedSymbol: globalSettings.editorHighlightSelectedSymbol,
            highlightDelay: clamped(globalSettings.editorHighlightDelay, min: 0.0, max: 5.0),
            wrapLines: globalSettings.editorWrapLines,
            indentWrappedLines: max(0, globalSettings.editorIndentWrappedLines),
            autoCompletionEnabled: globalSettings.editorEnableAutocomplete
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

    private static func resolveTokenPalette(globalSettings: GlobalSettings, project _: Project?, tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette {
        if let palette = globalSettings.defaultPalette(for: tone) {
            return palette
        }

        let alternateTone: SQLEditorPalette.Tone = tone == .light ? .dark : .light
        if let palette = globalSettings.defaultPalette(for: alternateTone) {
            return palette
        }

        if let legacy = palette(withID: globalSettings.defaultEditorTheme, globalSettings: globalSettings) {
            return legacy
        }

        let fallback = tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
        return SQLEditorTokenPalette(from: fallback)
    }

    private static func sanitizedFontName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        switch trimmed {
        case SQLEditorTheme.systemFontIdentifier, "System", "system", "MonospacedSystem", ".monospacedSystemFont", ".SystemMonospaced":
            return SQLEditorTheme.systemFontIdentifier
        case "IBMPlexMono-Regular":
            return "IBMPlexMono"
        case "Iosevka-Regular":
            return "Iosevka"
        default:
            return trimmed
        }
    }

    static func normalizedFontName(_ value: String?) -> String {
        sanitizedFontName(value) ?? SQLEditorTheme.defaultFontName
    }

    private static func palette(withID id: String, globalSettings: GlobalSettings) -> SQLEditorTokenPalette? {
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

extension SQLEditorTokenPalette.ResultGridColors {
    func style(for kind: ResultGridValueKind) -> SQLEditorTokenPalette.ResultGridStyle {
        switch kind {
        case .null: return null
        case .numeric: return numeric
        case .boolean: return boolean
        case .temporal: return temporal
        case .binary: return binary
        case .identifier: return identifier
        case .json: return json
        case .text:
#if os(macOS)
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(nsColor: .labelColor)))
#else
            return SQLEditorTokenPalette.ResultGridStyle(color: ColorRepresentable(color: Color(uiColor: .label)))
#endif
        }
    }
}
