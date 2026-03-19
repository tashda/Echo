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
extension SQLEditorTheme {
    var lineSpacing: CGFloat {
        let base = fontSize * 0.2
        return base * lineHeightMultiplier
    }
}
