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
    /// Round 28.1: SF Mono, the system's monospaced font.
    static let defaultFontName = systemFontIdentifier
    static let defaultFontFamily = systemFontIdentifier
    /// The default before round 28.1; settings still on it move to SF Mono once.
    static let formerDefaultFontNames: Set<String> = ["JetBrainsMono-Regular", "JetBrains Mono"]
    /// Families bundled in `Resources/Fonts`, all under the SIL Open Font License.
    static let bundledFontFamilies = [
        "JetBrains Mono", "Geist Mono", "Google Sans Code", "Intel One Mono", "Martian Mono", "Fragment Mono",
        "Atkinson Hyperlegible Mono", "Cascadia Code", "CommitMono",
        "Monaspace Neon Var", "Monaspace Argon Var", "Monaspace Xenon Var", "Monaspace Radon Var", "Monaspace Krypton Var",
    ]
    /// Picker names where a font's family name reads badly.
    static let bundledFontDisplayNames = [
        "CommitMono": "Commit Mono",
        "Monaspace Neon Var": "Monaspace Neon", "Monaspace Argon Var": "Monaspace Argon", "Monaspace Xenon Var": "Monaspace Xenon",
        "Monaspace Radon Var": "Monaspace Radon", "Monaspace Krypton Var": "Monaspace Krypton",
    ]
    static let systemFontIdentifier = "__system_monospaced__"
    static let defaultFontSize: CGFloat = 13
    static let defaultLineHeight: CGFloat = 1.55

    var fontName: String
    var fontSize: CGFloat
    var lineHeightMultiplier: CGFloat
    var ligaturesEnabled: Bool = false
    var surfaces: SQLEditorSurfaceColors
    var tokenPalette: SQLEditorTokenPalette
    var palette: SQLEditorTokenPalette { tokenPalette }

    init(
        fontName: String = SQLEditorTheme.defaultFontName,
        fontSize: CGFloat = SQLEditorTheme.defaultFontSize,
        lineHeightMultiplier: CGFloat = SQLEditorTheme.defaultLineHeight,
        ligaturesEnabled: Bool = false,
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
        ligaturesEnabled = try container.decodeIfPresent(Bool.self, forKey: .ligaturesEnabled) ?? false
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
        let basePalette = tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora
        let tokenPalette = SQLEditorTokenPalette(from: basePalette)

        let strongHighlight = SQLEditorTokenPalette.defaultSymbolHighlightStrong(
            selection: basePalette.selection,
            accent: nil,
            background: basePalette.background,
            isDark: tone == .dark
        )
        let brightHighlight = SQLEditorTokenPalette.defaultSymbolHighlightBright(
            selection: basePalette.selection,
            accent: nil,
            background: basePalette.background,
            isDark: tone == .dark
        )

        let surfaces = SQLEditorSurfaceColors(
            background: basePalette.background,
            text: basePalette.text,
            gutterBackground: basePalette.gutterBackground,
            gutterText: basePalette.gutterText,
            gutterAccent: basePalette.gutterAccent,
            selection: basePalette.selection,
            currentLine: basePalette.currentLine,
            symbolHighlightStrong: strongHighlight,
            symbolHighlightBright: brightHighlight
        )

        return SQLEditorTheme(
            surfaces: surfaces,
            tokenPalette: tokenPalette
        )
    }
}

