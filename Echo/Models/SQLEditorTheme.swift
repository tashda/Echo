import SwiftUI
import CoreGraphics
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SQLEditorTheme: Codable, Equatable {
    static let defaultFontName = "JetBrainsMono-Regular"
    static let defaultFontSize: CGFloat = 12
    static let defaultLineHeight: CGFloat = 1.0

    var fontName: String
    var fontSize: CGFloat
    var lineHeightMultiplier: CGFloat
    var palette: SQLEditorPalette

    init(
        fontName: String = SQLEditorTheme.defaultFontName,
        fontSize: CGFloat = SQLEditorTheme.defaultFontSize,
        lineHeightMultiplier: CGFloat = SQLEditorTheme.defaultLineHeight,
        palette: SQLEditorPalette = .aurora
    ) {
        self.fontName = fontName
        self.fontSize = fontSize
        self.lineHeightMultiplier = lineHeightMultiplier
        self.palette = palette
    }

    var tokenColors: SQLEditorPalette.TokenColors { palette.tokens }

    var font: NSFontWithFallback {
        NSFontWithFallback(name: fontName, size: fontSize)
    }

#if os(macOS)
    var nsFont: NSFont { font.font }
#else
    var uiFont: UIFont { font.font }
#endif
}

struct SQLEditorDisplayOptions: Codable, Equatable {
    var showLineNumbers: Bool
    var highlightSelectedSymbol: Bool
    var highlightDelay: Double
    var wrapLines: Bool
    var indentWrappedLines: Int

    init(
        showLineNumbers: Bool = true,
        highlightSelectedSymbol: Bool = true,
        highlightDelay: Double = 0.25,
        wrapLines: Bool = true,
        indentWrappedLines: Int = 4
    ) {
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedSymbol = highlightSelectedSymbol
        self.highlightDelay = highlightDelay
        self.wrapLines = wrapLines
        self.indentWrappedLines = indentWrappedLines
    }
}

struct SQLEditorPalette: Codable, Equatable, Hashable, Identifiable {
    enum Kind: String, Codable {
        case builtIn
        case custom
    }

    struct TokenColors: Codable, Equatable, Hashable {
        var primaryKeyword: ColorRepresentable
        var secondaryKeyword: ColorRepresentable
        var string: ColorRepresentable
        var number: ColorRepresentable
        var comment: ColorRepresentable
        var plain: ColorRepresentable
        var function: ColorRepresentable
        var operatorSymbol: ColorRepresentable
        var identifier: ColorRepresentable

        var keyword: ColorRepresentable { primaryKeyword }
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
            primaryKeyword: ColorRepresentable(hex: 0x3367D6),
            secondaryKeyword: ColorRepresentable(hex: 0x7B61FF),
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
            primaryKeyword: ColorRepresentable(hex: 0x7DD3FC),
            secondaryKeyword: ColorRepresentable(hex: 0xFBBF24),
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
            primaryKeyword: ColorRepresentable(hex: 0x268BD2),
            secondaryKeyword: ColorRepresentable(hex: 0xCB4B16),
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
            primaryKeyword: ColorRepresentable(hex: 0x0550AE),
            secondaryKeyword: ColorRepresentable(hex: 0x8250DF),
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
            primaryKeyword: ColorRepresentable(hex: 0x7287FD),
            secondaryKeyword: ColorRepresentable(hex: 0x8839EF),
            string: ColorRepresentable(hex: 0x40A02B),
            number: ColorRepresentable(hex: 0xDF8E1D),
            comment: ColorRepresentable(hex: 0x6C6F85),
            plain: ColorRepresentable(hex: 0x4C4F69),
            function: ColorRepresentable(hex: 0x209FB5),
            operatorSymbol: ColorRepresentable(hex: 0xE64553),
            identifier: ColorRepresentable(hex: 0x1E66F5)
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
            primaryKeyword: ColorRepresentable(hex: 0xC678DD),
            secondaryKeyword: ColorRepresentable(hex: 0xE06C75),
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
            primaryKeyword: ColorRepresentable(hex: 0xFF79C6),
            secondaryKeyword: ColorRepresentable(hex: 0xBD93F9),
            string: ColorRepresentable(hex: 0xF1FA8C),
            number: ColorRepresentable(hex: 0xBD93F9),
            comment: ColorRepresentable(hex: 0x6272A4),
            plain: ColorRepresentable(hex: 0xF8F8F2),
            function: ColorRepresentable(hex: 0x50FA7B),
            operatorSymbol: ColorRepresentable(hex: 0xFFB86C),
            identifier: ColorRepresentable(hex: 0x8BE9FD)
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
            primaryKeyword: ColorRepresentable(hex: 0x81A1C1),
            secondaryKeyword: ColorRepresentable(hex: 0x88C0D0),
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
        midnight,
        oneDark,
        dracula,
        nord
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
    static func resolve(globalSettings: GlobalSettings, project: Project?) -> SQLEditorTheme {
        let palette = resolvePalette(globalSettings: globalSettings, project: project)

        let projectFontName = sanitizedFontName(project?.settings.editorFontFamily)
        let globalFontName = sanitizedFontName(globalSettings.defaultEditorFontFamily)
        let fontName = projectFontName ?? globalFontName ?? SQLEditorTheme.defaultFontName
        let fontSizeValue = project?.settings.editorFontSize ?? globalSettings.defaultEditorFontSize
        let lineHeightValue = project?.settings.editorLineHeight ?? globalSettings.defaultEditorLineHeight

        let fontSize = max(8, CGFloat(fontSizeValue))
        let lineHeight = max(1.0, CGFloat(lineHeightValue))

        return SQLEditorTheme(
            fontName: fontName,
            fontSize: fontSize,
            lineHeightMultiplier: lineHeight,
            palette: palette
        )
    }

    static func resolveDisplayOptions(globalSettings: GlobalSettings, project: Project?) -> SQLEditorDisplayOptions {
        let showLineNumbers = project?.settings.showLineNumbers ?? globalSettings.editorShowLineNumbers
        let highlightSelected = project?.settings.highlightSelectedSymbol ?? globalSettings.editorHighlightSelectedSymbol
        let highlightDelay = clamped(project?.settings.highlightDelay ?? globalSettings.editorHighlightDelay, min: 0.0, max: 5.0)
        let wrapLines = project?.settings.wrapLines ?? globalSettings.editorWrapLines
        let indentWrappedLines = max(0, project?.settings.indentWrappedLines ?? globalSettings.editorIndentWrappedLines)

        return SQLEditorDisplayOptions(
            showLineNumbers: showLineNumbers,
            highlightSelectedSymbol: highlightSelected,
            highlightDelay: highlightDelay,
            wrapLines: wrapLines,
            indentWrappedLines: indentWrappedLines
        )
    }

    private static func resolvePalette(globalSettings: GlobalSettings, project: Project?) -> SQLEditorPalette {
        if let projectPalette = project?.settings.customEditorPalette {
            return projectPalette
        }

        if let paletteID = project?.settings.effectivePaletteIdentifier,
           let palette = palette(withID: paletteID, globalSettings: globalSettings, project: project) {
            return palette
        }

        if let palette = palette(withID: globalSettings.defaultEditorPaletteID, globalSettings: globalSettings, project: project) {
            return palette
        }

        if let legacy = palette(withID: globalSettings.defaultEditorTheme, globalSettings: globalSettings, project: project) {
            return legacy
        }

        return SQLEditorPalette.aurora
    }

    private static func sanitizedFontName(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func palette(withID id: String, globalSettings: GlobalSettings, project: Project?) -> SQLEditorPalette? {
        if let projectPalette = project?.settings.customEditorPalette, projectPalette.id == id {
            return projectPalette
        }

        if let custom = globalSettings.customEditorPalettes.first(where: { $0.id == id }) {
            return custom
        }

        return SQLEditorPalette.builtIn.first(where: { $0.id == id })
    }

    private static func clamped(_ value: Double, min: Double, max: Double) -> Double {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
