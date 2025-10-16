import Foundation
import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
#endif

struct AppColorTheme: Identifiable, Codable, Hashable {
    typealias ID = String

    var id: ID
    var name: String
    var tone: SQLEditorPalette.Tone
    var defaultPaletteID: String
    var isCustom: Bool
    var accent: ColorRepresentable?
    var swatchColors: [ColorRepresentable]
    var windowBackground: ColorRepresentable
    var surfaceBackground: ColorRepresentable
    var surfaceForeground: ColorRepresentable
    var editorBackground: ColorRepresentable
    var editorForeground: ColorRepresentable
    var editorGutterBackground: ColorRepresentable
    var editorGutterForeground: ColorRepresentable
    var editorSelection: ColorRepresentable
    var editorCurrentLine: ColorRepresentable
    var editorSymbolHighlightStrong: ColorRepresentable?
    var editorSymbolHighlightBright: ColorRepresentable?

    init(
        id: ID = UUID().uuidString,
        name: String,
        tone: SQLEditorPalette.Tone,
        defaultPaletteID: String,
        isCustom: Bool = true,
        accent: ColorRepresentable? = nil,
        swatchColors: [ColorRepresentable] = [],
        windowBackground: ColorRepresentable,
        surfaceBackground: ColorRepresentable,
        surfaceForeground: ColorRepresentable,
        editorBackground: ColorRepresentable,
        editorForeground: ColorRepresentable,
        editorGutterBackground: ColorRepresentable,
        editorGutterForeground: ColorRepresentable,
        editorSelection: ColorRepresentable,
        editorCurrentLine: ColorRepresentable,
        editorSymbolHighlightStrong: ColorRepresentable? = nil,
        editorSymbolHighlightBright: ColorRepresentable? = nil
    ) {
        self.id = id
        self.name = name
        self.tone = tone
        self.defaultPaletteID = defaultPaletteID
        self.isCustom = isCustom
        self.accent = accent
        self.swatchColors = swatchColors
        self.windowBackground = windowBackground
        self.surfaceBackground = surfaceBackground
        self.surfaceForeground = surfaceForeground
        self.editorBackground = editorBackground
        self.editorForeground = editorForeground
        self.editorGutterBackground = editorGutterBackground
        self.editorGutterForeground = editorGutterForeground
        self.editorSelection = editorSelection
        self.editorCurrentLine = editorCurrentLine
        self.editorSymbolHighlightStrong = editorSymbolHighlightStrong
        self.editorSymbolHighlightBright = editorSymbolHighlightBright
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case tone
        case paletteID
        case defaultPaletteID
        case isCustom
        case lightPaletteID
        case darkPaletteID
        case accent
        case swatchColors
        case windowBackground
        case surfaceBackground
        case surfaceForeground
        case editorBackground
        case editorForeground
        case editorGutterBackground
        case editorGutterForeground
        case editorSelection
        case editorCurrentLine
        case editorSymbolHighlightStrong
        case editorSymbolHighlightBright
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(ID.self, forKey: .id) ?? UUID().uuidString
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Theme"
        tone = try container.decodeIfPresent(SQLEditorPalette.Tone.self, forKey: .tone) ?? .light
        isCustom = try container.decodeIfPresent(Bool.self, forKey: .isCustom) ?? true
        accent = try container.decodeIfPresent(ColorRepresentable.self, forKey: .accent)

        let explicitDefaultPaletteID = try container.decodeIfPresent(String.self, forKey: .defaultPaletteID)
        let legacyPaletteID = try container.decodeIfPresent(String.self, forKey: .paletteID)
        let legacyLightID = try container.decodeIfPresent(String.self, forKey: .lightPaletteID)
        let legacyDarkID = try container.decodeIfPresent(String.self, forKey: .darkPaletteID)
        let toneValue = tone

        if let explicitDefaultPaletteID {
            defaultPaletteID = explicitDefaultPaletteID
        } else if let legacyPaletteID {
            defaultPaletteID = legacyPaletteID
        } else if tone == .dark, let legacyDarkID {
            defaultPaletteID = legacyDarkID
        } else if tone == .light, let legacyLightID {
            defaultPaletteID = legacyLightID
        } else if let fallbackBuiltIn = SQLEditorTokenPalette.builtIn.first(where: { $0.tone == toneValue }) {
            defaultPaletteID = fallbackBuiltIn.id
        } else {
            defaultPaletteID = tone == .dark ? SQLEditorPalette.midnight.id : SQLEditorPalette.aurora.id
        }

        let fallbackTheme = AppColorTheme.fallbackTheme(for: tone, defaultPaletteID: defaultPaletteID, themeID: id)

        windowBackground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .windowBackground) ?? fallbackTheme.windowBackground
        surfaceBackground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .surfaceBackground) ?? fallbackTheme.surfaceBackground
        surfaceForeground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .surfaceForeground) ?? fallbackTheme.surfaceForeground
        editorBackground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorBackground) ?? fallbackTheme.editorBackground
        editorForeground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorForeground) ?? fallbackTheme.editorForeground
        editorGutterBackground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorGutterBackground) ?? fallbackTheme.editorGutterBackground
        editorGutterForeground = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorGutterForeground) ?? fallbackTheme.editorGutterForeground
        editorSelection = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorSelection) ?? fallbackTheme.editorSelection
        editorCurrentLine = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorCurrentLine) ?? fallbackTheme.editorCurrentLine
        editorSymbolHighlightStrong = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorSymbolHighlightStrong) ?? fallbackTheme.editorSymbolHighlightStrong
        editorSymbolHighlightBright = try container.decodeIfPresent(ColorRepresentable.self, forKey: .editorSymbolHighlightBright) ?? fallbackTheme.editorSymbolHighlightBright

        if let decodedSwatches = try container.decodeIfPresent([ColorRepresentable].self, forKey: .swatchColors), !decodedSwatches.isEmpty {
            swatchColors = decodedSwatches
        } else if !fallbackTheme.swatchColors.isEmpty {
            swatchColors = fallbackTheme.swatchColors
        } else if let palette = SQLEditorPalette.palette(withID: defaultPaletteID) {
            swatchColors = [
                palette.tokens.keyword.color,
                palette.tokens.string.color,
                palette.tokens.operatorSymbol.color,
                palette.tokens.identifier.color,
                palette.tokens.comment.color
            ]
        } else {
            swatchColors = []
        }

        if accent == nil {
            accent = fallbackTheme.accent ?? swatchColors.first
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tone, forKey: .tone)
        try container.encode(defaultPaletteID, forKey: .defaultPaletteID)
        try container.encode(defaultPaletteID, forKey: .paletteID)
        try container.encode(isCustom, forKey: .isCustom)
        try container.encodeIfPresent(accent, forKey: .accent)
        try container.encode(swatchColors, forKey: .swatchColors)
        try container.encode(windowBackground, forKey: .windowBackground)
        try container.encode(surfaceBackground, forKey: .surfaceBackground)
        try container.encode(surfaceForeground, forKey: .surfaceForeground)
        try container.encode(editorBackground, forKey: .editorBackground)
        try container.encode(editorForeground, forKey: .editorForeground)
        try container.encode(editorGutterBackground, forKey: .editorGutterBackground)
        try container.encode(editorGutterForeground, forKey: .editorGutterForeground)
        try container.encode(editorSelection, forKey: .editorSelection)
        try container.encode(editorCurrentLine, forKey: .editorCurrentLine)
        try container.encodeIfPresent(editorSymbolHighlightStrong, forKey: .editorSymbolHighlightStrong)
        try container.encodeIfPresent(editorSymbolHighlightBright, forKey: .editorSymbolHighlightBright)

        if tone == .light {
            try container.encode(defaultPaletteID, forKey: .lightPaletteID)
        } else {
            try container.encode(defaultPaletteID, forKey: .darkPaletteID)
        }
    }

    func resolvedAccent(using paletteProvider: (String) -> SQLEditorTokenPalette?) -> ColorRepresentable {
        if let accent {
            return accent
        }
        if let palette = paletteProvider(defaultPaletteID) {
            return palette.tokens.keyword.color
        }
        return tone == .dark ? ColorRepresentable(hex: 0x60A5FA) : ColorRepresentable(hex: 0x2563EB)
    }

    static func fromPalette(_ palette: SQLEditorPalette, idOverride: String? = nil, isCustom: Bool? = nil) -> AppColorTheme {
        let resolvedID: String
        if let idOverride {
            resolvedID = idOverride
        } else if palette.kind == .custom {
            resolvedID = palette.id
        } else {
            resolvedID = "builtin-\(palette.id)"
        }

        return AppColorTheme(
            id: resolvedID,
            name: palette.name,
            tone: palette.tone,
            defaultPaletteID: palette.id,
            isCustom: isCustom ?? (palette.kind == .custom),
            accent: palette.tokens.keyword.color,
            swatchColors: [
                palette.tokens.keyword.color,
                palette.tokens.string.color,
                palette.tokens.operatorSymbol.color,
                palette.tokens.identifier.color,
                palette.tokens.comment.color
            ],
            windowBackground: palette.background,
            surfaceBackground: palette.gutterBackground,
            surfaceForeground: palette.text,
            editorBackground: palette.background,
            editorForeground: palette.text,
            editorGutterBackground: palette.gutterBackground,
            editorGutterForeground: palette.gutterText,
            editorSelection: palette.selection,
            editorCurrentLine: palette.currentLine
        )
    }

}

private struct BuiltInThemeDefinition {
    let identifier: String
    let name: String
    let tone: SQLEditorPalette.Tone
    let defaultPaletteID: String
    let accent: ColorRepresentable
    let windowBackground: ColorRepresentable
    let surfaceBackground: ColorRepresentable
    let surfaceForeground: ColorRepresentable
    let swatches: [ColorRepresentable]?

    func makeTheme(fallbackPaletteID: String) -> AppColorTheme {
        let palette = SQLEditorPalette.palette(withID: defaultPaletteID)
            ?? SQLEditorPalette.palette(withID: fallbackPaletteID)
            ?? (tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora)

        let strongHighlight = SQLEditorTokenPalette.defaultSymbolHighlightStrong(
            selection: palette.selection,
            accent: accent,
            background: palette.background,
            isDark: tone == .dark
        )

        let brightHighlight = SQLEditorTokenPalette.defaultSymbolHighlightBright(
            selection: palette.selection,
            accent: accent,
            background: palette.background,
            isDark: tone == .dark
        )

        let defaultSwatches = [
            accent,
            palette.tokens.keyword.color,
            palette.tokens.string.color,
            palette.tokens.operatorSymbol.color,
            palette.tokens.comment.color
        ]

        return AppColorTheme(
            id: "builtin-\(identifier)-\(tone.rawValue)",
            name: name,
            tone: tone,
            defaultPaletteID: palette.id,
            isCustom: false,
            accent: accent,
            swatchColors: swatches ?? defaultSwatches,
            windowBackground: windowBackground,
            surfaceBackground: surfaceBackground,
            surfaceForeground: surfaceForeground,
            editorBackground: palette.background,
            editorForeground: palette.text,
            editorGutterBackground: palette.gutterBackground,
            editorGutterForeground: palette.gutterText,
            editorSelection: palette.selection,
            editorCurrentLine: palette.currentLine,
            editorSymbolHighlightStrong: strongHighlight,
            editorSymbolHighlightBright: brightHighlight
        )
    }
}

extension AppColorTheme {
    private static let builtInThemeCatalog: [BuiltInThemeDefinition] = [
        BuiltInThemeDefinition(
            identifier: "echo",
            name: "Echo Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.echoLight.id,
            accent: ColorRepresentable(hex: 0x0A84FF),
            windowBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1C1C1E),
            swatches: [
                ColorRepresentable(hex: 0x0A84FF),
                ColorRepresentable(hex: 0x30D158),
                ColorRepresentable(hex: 0xFF9F0A),
                ColorRepresentable(hex: 0xFF375F),
                ColorRepresentable(hex: 0x8E8E93)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Light+",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x007ACC),
            windowBackground: ColorRepresentable(hex: 0xF5F7FE),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2329),
            swatches: [
                ColorRepresentable(hex: 0x007ACC),
                ColorRepresentable(hex: 0x1F6FEB),
                ColorRepresentable(hex: 0xD83B01),
                ColorRepresentable(hex: 0x117E67),
                ColorRepresentable(hex: 0x5E6A7D)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "sunrise",
            name: "Solarized Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.solstice.id,
            accent: ColorRepresentable(hex: 0x268BD2),
            windowBackground: ColorRepresentable(hex: 0xFDF6E3),
            surfaceBackground: ColorRepresentable(hex: 0xFFFDF0),
            surfaceForeground: ColorRepresentable(hex: 0x586E75),
            swatches: [
                ColorRepresentable(hex: 0x268BD2),
                ColorRepresentable(hex: 0x2AA198),
                ColorRepresentable(hex: 0xB58900),
                ColorRepresentable(hex: 0xCB4B16),
                ColorRepresentable(hex: 0x6C71C4)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "meadow",
            name: "Catppuccin Latte",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.catppuccinLatte.id,
            accent: ColorRepresentable(hex: 0x7287FD),
            windowBackground: ColorRepresentable(hex: 0xF4F1FB),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x4C4F69),
            swatches: [
                ColorRepresentable(hex: 0x7287FD),
                ColorRepresentable(hex: 0x40A02B),
                ColorRepresentable(hex: 0xDF8E1D),
                ColorRepresentable(hex: 0xE64553),
                ColorRepresentable(hex: 0x179299)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "slate",
            name: "GitHub Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.githubLight.id,
            accent: ColorRepresentable(hex: 0x0969DA),
            windowBackground: ColorRepresentable(hex: 0xF6F8FA),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2328),
            swatches: [
                ColorRepresentable(hex: 0x0969DA),
                ColorRepresentable(hex: 0x1F2328),
                ColorRepresentable(hex: 0x953800),
                ColorRepresentable(hex: 0x116329),
                ColorRepresentable(hex: 0x6E7781)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "cascade",
            name: "Nord Snow",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.orchard.id,
            accent: ColorRepresentable(hex: 0x5E81AC),
            windowBackground: ColorRepresentable(hex: 0xE5EEF6),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2E3440),
            swatches: [
                ColorRepresentable(hex: 0x5E81AC),
                ColorRepresentable(hex: 0x88C0D0),
                ColorRepresentable(hex: 0xA3BE8C),
                ColorRepresentable(hex: 0xBF616A),
                ColorRepresentable(hex: 0xEBCB8B)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "pearl",
            name: "One Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.paperwhite.id,
            accent: ColorRepresentable(hex: 0x7C61C9),
            windowBackground: ColorRepresentable(hex: 0xF8F9FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2B2D33),
            swatches: [
                ColorRepresentable(hex: 0x7C61C9),
                ColorRepresentable(hex: 0x50A14F),
                ColorRepresentable(hex: 0x986801),
                ColorRepresentable(hex: 0x0184BC),
                ColorRepresentable(hex: 0xE45649)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "harbor",
            name: "Sea Breeze",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.seaBreeze.id,
            accent: ColorRepresentable(hex: 0x0EA5E9),
            windowBackground: ColorRepresentable(hex: 0xEFF6FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x10203A),
            swatches: [
                ColorRepresentable(hex: 0x0EA5E9),
                ColorRepresentable(hex: 0x22D3EE),
                ColorRepresentable(hex: 0x1E8B6F),
                ColorRepresentable(hex: 0x0A75C2),
                ColorRepresentable(hex: 0x94A3B8)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "citrus",
            name: "Monokai Daybreak",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.emberLight.id,
            accent: ColorRepresentable(hex: 0xFC9867),
            windowBackground: ColorRepresentable(hex: 0xFFF4EB),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x2F2117),
            swatches: [
                ColorRepresentable(hex: 0xFC9867),
                ColorRepresentable(hex: 0xFFD866),
                ColorRepresentable(hex: 0xA9DC76),
                ColorRepresentable(hex: 0x78DCE8),
                ColorRepresentable(hex: 0xAB9DF2)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "evergreen",
            name: "Quiet Light",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x3B76F6),
            windowBackground: ColorRepresentable(hex: 0xF7F8FC),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x1F2933),
            swatches: [
                ColorRepresentable(hex: 0x3B76F6),
                ColorRepresentable(hex: 0x60A5FA),
                ColorRepresentable(hex: 0x1F6FEB),
                ColorRepresentable(hex: 0x2A5CBF),
                ColorRepresentable(hex: 0x6B7280)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "tahoe",
            name: "Tahoe",
            tone: .light,
            defaultPaletteID: SQLEditorPalette.aurora.id,
            accent: ColorRepresentable(hex: 0x2F5FFF),
            windowBackground: ColorRepresentable(hex: 0xEEF3FF),
            surfaceBackground: ColorRepresentable(hex: 0xFFFFFF),
            surfaceForeground: ColorRepresentable(hex: 0x0F1A2B),
            swatches: [
                ColorRepresentable(hex: 0x2F5FFF),
                ColorRepresentable(hex: 0x2563EB),
                ColorRepresentable(hex: 0x38BDF8),
                ColorRepresentable(hex: 0x60A5FA),
                ColorRepresentable(hex: 0x0F172A)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Dark+",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.midnight.id,
            accent: ColorRepresentable(hex: 0x569CD6),
            windowBackground: ColorRepresentable(hex: 0x1E1E1E),
            surfaceBackground: ColorRepresentable(hex: 0x252526),
            surfaceForeground: ColorRepresentable(hex: 0xD4D4D4),
            swatches: [
                ColorRepresentable(hex: 0x569CD6),
                ColorRepresentable(hex: 0xCE9178),
                ColorRepresentable(hex: 0xC586C0),
                ColorRepresentable(hex: 0xB5CEA8),
                ColorRepresentable(hex: 0x6A9955)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "echo",
            name: "Echo Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.echoDark.id,
            accent: ColorRepresentable(hex: 0x0A84FF),
            windowBackground: ColorRepresentable(hex: 0x12131B),
            surfaceBackground: ColorRepresentable(hex: 0x1D1E27),
            surfaceForeground: ColorRepresentable(hex: 0xF2F2F7),
            swatches: [
                ColorRepresentable(hex: 0x0A84FF),
                ColorRepresentable(hex: 0x30D158),
                ColorRepresentable(hex: 0xFF9F0A),
                ColorRepresentable(hex: 0xFF453A),
                ColorRepresentable(hex: 0xAEAEB2)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "neon",
            name: "Dracula",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.dracula.id,
            accent: ColorRepresentable(hex: 0xFF79C6),
            windowBackground: ColorRepresentable(hex: 0x1E1F2A),
            surfaceBackground: ColorRepresentable(hex: 0x282A36),
            surfaceForeground: ColorRepresentable(hex: 0xF8F8F2),
            swatches: [
                ColorRepresentable(hex: 0xFF79C6),
                ColorRepresentable(hex: 0x50FA7B),
                ColorRepresentable(hex: 0xBD93F9),
                ColorRepresentable(hex: 0xFFB86C),
                ColorRepresentable(hex: 0x8BE9FD)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "aurora",
            name: "Night Owl",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.nebulaNight.id,
            accent: ColorRepresentable(hex: 0x82AAFF),
            windowBackground: ColorRepresentable(hex: 0x0B1D32),
            surfaceBackground: ColorRepresentable(hex: 0x15243B),
            surfaceForeground: ColorRepresentable(hex: 0xD6DEEB),
            swatches: [
                ColorRepresentable(hex: 0x82AAFF),
                ColorRepresentable(hex: 0x7DE2CF),
                ColorRepresentable(hex: 0xF6C177),
                ColorRepresentable(hex: 0x5D6A85),
                ColorRepresentable(hex: 0x9F7BFF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "carbon",
            name: "Carbon",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.charcoal.id,
            accent: ColorRepresentable(hex: 0x64A9F6),
            windowBackground: ColorRepresentable(hex: 0x12131C),
            surfaceBackground: ColorRepresentable(hex: 0x181B24),
            surfaceForeground: ColorRepresentable(hex: 0xD8DEE6),
            swatches: [
                ColorRepresentable(hex: 0x64A9F6),
                ColorRepresentable(hex: 0x4BD0A0),
                ColorRepresentable(hex: 0xF2A65A),
                ColorRepresentable(hex: 0xF5546B),
                ColorRepresentable(hex: 0x8AD1FF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "obsidian",
            name: "One Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.oneDark.id,
            accent: ColorRepresentable(hex: 0x61AFEF),
            windowBackground: ColorRepresentable(hex: 0x22262E),
            surfaceBackground: ColorRepresentable(hex: 0x282C34),
            surfaceForeground: ColorRepresentable(hex: 0xABB2BF),
            swatches: [
                ColorRepresentable(hex: 0x61AFEF),
                ColorRepresentable(hex: 0x98C379),
                ColorRepresentable(hex: 0xC678DD),
                ColorRepresentable(hex: 0xE06C75),
                ColorRepresentable(hex: 0xE5C07B)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "lunar",
            name: "Nord",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.nord.id,
            accent: ColorRepresentable(hex: 0x88C0D0),
            windowBackground: ColorRepresentable(hex: 0x1F242E),
            surfaceBackground: ColorRepresentable(hex: 0x2E3440),
            surfaceForeground: ColorRepresentable(hex: 0xECEFF4),
            swatches: [
                ColorRepresentable(hex: 0x88C0D0),
                ColorRepresentable(hex: 0x5E81AC),
                ColorRepresentable(hex: 0x8FBCBB),
                ColorRepresentable(hex: 0xA3BE8C),
                ColorRepresentable(hex: 0xBF616A)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "velvet",
            name: "Tokyo Night",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.violetStorm.id,
            accent: ColorRepresentable(hex: 0x7AA2F7),
            windowBackground: ColorRepresentable(hex: 0x161725),
            surfaceBackground: ColorRepresentable(hex: 0x1A1B26),
            surfaceForeground: ColorRepresentable(hex: 0xA9B1D6),
            swatches: [
                ColorRepresentable(hex: 0x7AA2F7),
                ColorRepresentable(hex: 0x9ECE6A),
                ColorRepresentable(hex: 0xF78C6C),
                ColorRepresentable(hex: 0x2AC3DE),
                ColorRepresentable(hex: 0xC099FF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "ember",
            name: "Monokai",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.emberDark.id,
            accent: ColorRepresentable(hex: 0xF92672),
            windowBackground: ColorRepresentable(hex: 0x201F1F),
            surfaceBackground: ColorRepresentable(hex: 0x272822),
            surfaceForeground: ColorRepresentable(hex: 0xF8F8F2),
            swatches: [
                ColorRepresentable(hex: 0xF92672),
                ColorRepresentable(hex: 0xA6E22E),
                ColorRepresentable(hex: 0x66D9EF),
                ColorRepresentable(hex: 0xFD971F),
                ColorRepresentable(hex: 0xE6DB74)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "noir",
            name: "Catppuccin Mocha",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.catppuccinMocha.id,
            accent: ColorRepresentable(hex: 0xCBA6F7),
            windowBackground: ColorRepresentable(hex: 0x171727),
            surfaceBackground: ColorRepresentable(hex: 0x1E1E2E),
            surfaceForeground: ColorRepresentable(hex: 0xCDD6F4),
            swatches: [
                ColorRepresentable(hex: 0xCBA6F7),
                ColorRepresentable(hex: 0xA6E3A1),
                ColorRepresentable(hex: 0xF5C2E7),
                ColorRepresentable(hex: 0x94E2D5),
                ColorRepresentable(hex: 0x89B4FA)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "dusk",
            name: "Solarized Dark",
            tone: .dark,
            defaultPaletteID: SQLEditorPalette.solarizedDark.id,
            accent: ColorRepresentable(hex: 0x268BD2),
            windowBackground: ColorRepresentable(hex: 0x001F27),
            surfaceBackground: ColorRepresentable(hex: 0x002B36),
            surfaceForeground: ColorRepresentable(hex: 0x93A1A1),
            swatches: [
                ColorRepresentable(hex: 0x268BD2),
                ColorRepresentable(hex: 0x2AA198),
                ColorRepresentable(hex: 0xB58900),
                ColorRepresentable(hex: 0xCB4B16),
                ColorRepresentable(hex: 0x859900)
            ]
        )
    ]

    static func builtInThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        let fallbackPaletteID = tone == .light ? SQLEditorPalette.aurora.id : SQLEditorPalette.midnight.id
        return builtInThemeCatalog
            .filter { $0.tone == tone }
            .map { $0.makeTheme(fallbackPaletteID: fallbackPaletteID) }
    }

    static func fallbackTheme(for tone: SQLEditorPalette.Tone, defaultPaletteID: String, themeID: AppColorTheme.ID? = nil) -> AppColorTheme {
        if let themeID,
           let idMatch = builtInThemes(for: tone).first(where: { $0.id == themeID }) {
            return idMatch
        }
        if let builtInMatch = builtInThemes(for: tone).first(where: { $0.defaultPaletteID == defaultPaletteID }) {
            return builtInMatch
        }
        if let palette = SQLEditorPalette.palette(withID: defaultPaletteID) {
            return AppColorTheme.fromPalette(palette, idOverride: "builtin-\(palette.id)", isCustom: false)
        }
        return tone == .dark ? AppColorTheme.fromPalette(.midnight) : AppColorTheme.fromPalette(.aurora)
    }
}

// MARK: - Project

struct Project: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date
    var colorHex: String
    var iconName: String?
    var isDefault: Bool

    // Project-specific settings
    var settings: ProjectSettings
    var bookmarks: [Bookmark]


    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        colorHex: String = "",
        iconName: String? = nil,
        isDefault: Bool = false,
        settings: ProjectSettings = ProjectSettings(),
        bookmarks: [Bookmark] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorHex = colorHex
        self.iconName = iconName
        self.isDefault = isDefault
        self.settings = settings
        self.bookmarks = bookmarks
    }

    static let defaultProject = Project(
        name: "Default",
        colorHex: "007AFF",
        isDefault: true,
        bookmarks: []
    )
}

extension Project {
    var color: Color {
        Color(hex: colorHex) ?? .accentColor
    }

    mutating func updateColor(_ color: Color) {
        colorHex = color.toHex() ?? ""
    }

    var iconRenderInfo: (image: Image, isSystemSymbol: Bool) {
        guard let iconName, !iconName.isEmpty else {
            return (Image(systemName: "folder.badge.gearshape"), true)
        }

        #if canImport(AppKit)
        if NSImage(named: iconName) != nil {
            return (Image(iconName), false)
        }

        if NSImage(systemSymbolName: iconName, accessibilityDescription: nil) != nil {
            return (Image(systemName: iconName), true)
        }
        #endif

        return (Image(systemName: "folder.badge.gearshape"), true)
    }
}

// MARK: - Project Settings

struct ProjectSettings: Codable, Hashable {
    // SQL Editor settings
    var editorFontSize: Double?
    var editorFontFamily: String?
    var editorTheme: String? // Legacy identifier kept for backward compatibility
    var editorPaletteID: String?
    var customEditorPalette: SQLEditorTokenPalette?
    var editorLineHeight: Double?
    var showLineNumbers: Bool?
    var highlightSelectedSymbol: Bool?
    var highlightDelay: Double?
    var wrapLines: Bool?
    var indentWrappedLines: Int?
    var enableAutocomplete: Bool?

    // UI Preferences
    var useServerColorAsAccent: Bool?
    var defaultSchemaFilter: String?

    // Future settings can be added here
    var customSettings: [String: String]

    init(
        editorFontSize: Double? = nil,
        editorFontFamily: String? = nil,
        editorTheme: String? = nil,
        editorPaletteID: String? = nil,
        customEditorPalette: SQLEditorTokenPalette? = nil,
        editorLineHeight: Double? = nil,
        showLineNumbers: Bool? = nil,
        highlightSelectedSymbol: Bool? = nil,
        highlightDelay: Double? = nil,
        wrapLines: Bool? = nil,
        indentWrappedLines: Int? = nil,
        enableAutocomplete: Bool? = nil,
        useServerColorAsAccent: Bool? = nil,
        defaultSchemaFilter: String? = nil,
        customSettings: [String: String] = [:]
    ) {
        self.editorFontSize = editorFontSize
        self.editorFontFamily = editorFontFamily
        self.editorTheme = editorTheme
        self.editorPaletteID = editorPaletteID
        self.customEditorPalette = customEditorPalette
        self.editorLineHeight = editorLineHeight
        self.showLineNumbers = showLineNumbers
        self.highlightSelectedSymbol = highlightSelectedSymbol
        self.highlightDelay = highlightDelay
        self.wrapLines = wrapLines
        self.indentWrappedLines = indentWrappedLines
        self.enableAutocomplete = enableAutocomplete
        self.useServerColorAsAccent = useServerColorAsAccent
        self.defaultSchemaFilter = defaultSchemaFilter
        self.customSettings = customSettings
    }

    private enum CodingKeys: String, CodingKey {
        case editorFontSize
        case editorFontFamily
        case editorTheme
        case editorPaletteID
        case customEditorPalette
        case editorLineHeight
        case showLineNumbers
        case highlightSelectedSymbol
        case highlightDelay
        case wrapLines
        case indentWrappedLines
        case enableAutocomplete
        case useServerColorAsAccent
        case defaultSchemaFilter
        case customSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        editorFontSize = try container.decodeIfPresent(Double.self, forKey: .editorFontSize)
        editorFontFamily = try container.decodeIfPresent(String.self, forKey: .editorFontFamily)
        editorTheme = try container.decodeIfPresent(String.self, forKey: .editorTheme)
        editorPaletteID = try container.decodeIfPresent(String.self, forKey: .editorPaletteID)

        if let palette = try container.decodeIfPresent(SQLEditorTokenPalette.self, forKey: .customEditorPalette) {
            customEditorPalette = palette
        } else if let legacyPalette = try container.decodeIfPresent(SQLEditorPalette.self, forKey: .customEditorPalette) {
            customEditorPalette = SQLEditorTokenPalette(from: legacyPalette)
        } else {
            customEditorPalette = nil
        }

        editorLineHeight = try container.decodeIfPresent(Double.self, forKey: .editorLineHeight)
        showLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .showLineNumbers)
        highlightSelectedSymbol = try container.decodeIfPresent(Bool.self, forKey: .highlightSelectedSymbol)
        highlightDelay = try container.decodeIfPresent(Double.self, forKey: .highlightDelay)
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines)
        indentWrappedLines = try container.decodeIfPresent(Int.self, forKey: .indentWrappedLines)
        enableAutocomplete = try container.decodeIfPresent(Bool.self, forKey: .enableAutocomplete)
        useServerColorAsAccent = try container.decodeIfPresent(Bool.self, forKey: .useServerColorAsAccent)
        defaultSchemaFilter = try container.decodeIfPresent(String.self, forKey: .defaultSchemaFilter)
        customSettings = try container.decodeIfPresent([String: String].self, forKey: .customSettings) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(editorFontSize, forKey: .editorFontSize)
        try container.encodeIfPresent(editorFontFamily, forKey: .editorFontFamily)
        try container.encodeIfPresent(editorTheme, forKey: .editorTheme)
        try container.encodeIfPresent(editorPaletteID, forKey: .editorPaletteID)
        try container.encodeIfPresent(customEditorPalette, forKey: .customEditorPalette)
        try container.encodeIfPresent(editorLineHeight, forKey: .editorLineHeight)
        try container.encodeIfPresent(showLineNumbers, forKey: .showLineNumbers)
        try container.encodeIfPresent(highlightSelectedSymbol, forKey: .highlightSelectedSymbol)
        try container.encodeIfPresent(highlightDelay, forKey: .highlightDelay)
        try container.encodeIfPresent(wrapLines, forKey: .wrapLines)
        try container.encodeIfPresent(indentWrappedLines, forKey: .indentWrappedLines)
        try container.encodeIfPresent(enableAutocomplete, forKey: .enableAutocomplete)
        try container.encodeIfPresent(useServerColorAsAccent, forKey: .useServerColorAsAccent)
        try container.encodeIfPresent(defaultSchemaFilter, forKey: .defaultSchemaFilter)
        if !customSettings.isEmpty {
            try container.encode(customSettings, forKey: .customSettings)
        }
    }
}

extension ProjectSettings {
    var effectivePaletteIdentifier: String? {
        editorPaletteID ?? editorTheme
    }
}

extension GlobalSettings {
    var defaultEditorPaletteID: String {
        get { defaultEditorPaletteIDLight }
        set { defaultEditorPaletteIDLight = newValue }
    }

    var availablePalettes: [SQLEditorTokenPalette] {
        var combined = SQLEditorTokenPalette.builtIn
        for palette in customEditorPalettes where !combined.contains(where: { $0.id == palette.id }) {
            combined.append(palette)
        }
        return combined
    }

    func palette(withID id: String) -> SQLEditorTokenPalette? {
        SQLEditorTokenPalette.palette(withID: id, customPalettes: customEditorPalettes)
    }

    func defaultPaletteID(for tone: SQLEditorPalette.Tone) -> String {
        switch tone {
        case .light:
            return defaultEditorPaletteIDLight
        case .dark:
            return defaultEditorPaletteIDDark
        }
    }

    mutating func setDefaultPaletteID(_ id: String, for tone: SQLEditorPalette.Tone) {
        switch tone {
        case .light:
            defaultEditorPaletteIDLight = id
        case .dark:
            defaultEditorPaletteIDDark = id
        }
    }

    func defaultPalette(for tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette? {
        palette(withID: defaultPaletteID(for: tone))
    }

    func availableThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        let builtIn = AppColorTheme.builtInThemes(for: tone)
        let customs = customThemes.filter { $0.tone == tone }
        func priority(_ theme: AppColorTheme) -> Int {
            if theme.id.hasPrefix("builtin-echo-") {
                return 0
            }
            if !theme.isCustom {
                return 1
            }
            return 2
        }

        return (builtIn + customs).sorted { lhs, rhs in
            let lhsPriority = priority(lhs)
            let rhsPriority = priority(rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func ligaturesEnabled(for fontName: String) -> Bool {
        let key = SQLEditorThemeResolver.normalizedFontName(fontName)
        if let override = fontLigatureOverrides[key] {
            return override
        }
        return Self.defaultLigatureFonts.contains(key)
    }

    mutating func setLigaturesEnabled(_ enabled: Bool, for fontName: String) {
        let key = SQLEditorThemeResolver.normalizedFontName(fontName)
        let defaultValue = Self.defaultLigatureFonts.contains(key)
        if enabled == defaultValue {
            fontLigatureOverrides.removeValue(forKey: key)
        } else {
            fontLigatureOverrides[key] = enabled
        }
    }

    static let defaultLigatureFonts: Set<String> = [
        "FiraCode-Regular",
        "JetBrainsMono-Regular",
        "Iosevka"
    ]

    func activeThemeID(for tone: SQLEditorPalette.Tone) -> AppColorTheme.ID? {
        switch tone {
        case .light:
            return activeThemeIDLight
        case .dark:
            return activeThemeIDDark
        }
    }

    mutating func setActiveThemeID(_ id: AppColorTheme.ID?, for tone: SQLEditorPalette.Tone) {
        switch tone {
        case .light:
            activeThemeIDLight = id
        case .dark:
            activeThemeIDDark = id
        }
    }

    func theme(withID id: AppColorTheme.ID?, tone: SQLEditorPalette.Tone) -> AppColorTheme? {
        guard let id else { return nil }
        return availableThemes(for: tone).first { $0.id == id }
    }

    func themeMatchingCurrentPalette(for tone: SQLEditorPalette.Tone) -> AppColorTheme? {
        let targetPaletteID = defaultPaletteID(for: tone)
        let themes = availableThemes(for: tone)
        if let matched = themes.first(where: { $0.defaultPaletteID == targetPaletteID }) {
            return matched
        }
        return themes.first
    }
}

// MARK: - Global Settings

enum ForeignKeyDisplayMode: String, Codable, CaseIterable, Hashable, Sendable {
    case showInspector
    case showIcon
    case disabled
}

enum ForeignKeyInspectorBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case respectInspectorVisibility
    case autoOpenAndClose
}

struct GlobalSettings: Codable, Hashable {
    // Global UI preferences
    var appearanceMode: AppearanceMode
    var defaultEditorFontSize: Double
    var defaultEditorFontFamily: String
    var defaultEditorTheme: String // Legacy identifier kept for backward compatibility
    var fontLigatureOverrides: [String: Bool]
    var lastCustomEditorFontFamily: String?
    var defaultEditorPaletteIDLight: String
    var defaultEditorPaletteIDDark: String
    var customEditorPalettes: [SQLEditorTokenPalette]
    var customThemes: [AppColorTheme]
    var defaultEditorLineHeight: Double
    var editorShowLineNumbers: Bool = true
    var editorHighlightSelectedSymbol: Bool = true
    var editorHighlightDelay: Double = 0.25
    var editorWrapLines: Bool = true
    var editorIndentWrappedLines: Int = 4
    var editorEnableAutocomplete: Bool = true
    var useServerColorAsAccent: Bool
    var activeThemeIDLight: AppColorTheme.ID?
    var activeThemeIDDark: AppColorTheme.ID?
    var themeTabs: Bool = false
    var themeResultsGrid: Bool = true
    var resultsAlternateRowShading: Bool = false
    var foreignKeyDisplayMode: ForeignKeyDisplayMode = .showInspector
    var foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior = .respectInspectorVisibility
    var foreignKeyIncludeRelated: Bool = false
    var resultsInitialRowLimit: Int = 500
    var resultsPreviewBatchSize: Int = 500
    var resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024
    var resultSpoolRetentionHours: Int = 72
    var resultSpoolCustomLocation: String?
    var inspectorWidth: Double?
    var keepTabsInMemory: Bool = false

    // Window preferences
    var defaultWindowWidth: Double?
    var defaultWindowHeight: Double?

    init(
        appearanceMode: AppearanceMode = .system,
        defaultEditorFontSize: Double = 12.0,
        defaultEditorFontFamily: String = "JetBrainsMono-Regular",
        defaultEditorTheme: String = SQLEditorPalette.aurora.id,
        fontLigatureOverrides: [String: Bool] = [:],
        lastCustomEditorFontFamily: String? = nil,
        defaultEditorPaletteIDLight: String = SQLEditorPalette.aurora.id,
        defaultEditorPaletteIDDark: String = SQLEditorPalette.midnight.id,
        customEditorPalettes: [SQLEditorTokenPalette] = [],
        customThemes: [AppColorTheme] = [],
        defaultEditorLineHeight: Double = Double(SQLEditorTheme.defaultLineHeight),
        editorShowLineNumbers: Bool = true,
        editorHighlightSelectedSymbol: Bool = true,
        editorHighlightDelay: Double = 0.25,
        editorWrapLines: Bool = true,
        editorIndentWrappedLines: Int = 4,
        editorEnableAutocomplete: Bool = true,
        useServerColorAsAccent: Bool = true,
        themeTabs: Bool = false,
        themeResultsGrid: Bool = true,
        resultsAlternateRowShading: Bool = false,
        foreignKeyDisplayMode: ForeignKeyDisplayMode = .showInspector,
        foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior = .respectInspectorVisibility,
        foreignKeyIncludeRelated: Bool = false,
        resultsInitialRowLimit: Int = 500,
        resultsPreviewBatchSize: Int = 500,
        resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024,
        resultSpoolRetentionHours: Int = 72,
        resultSpoolCustomLocation: String? = nil,
        inspectorWidth: Double? = nil,
        defaultWindowWidth: Double? = nil,
        defaultWindowHeight: Double? = nil,
        activeThemeIDLight: AppColorTheme.ID? = nil,
        activeThemeIDDark: AppColorTheme.ID? = nil,
        keepTabsInMemory: Bool = false
    ) {
        self.appearanceMode = appearanceMode
        self.defaultEditorFontSize = defaultEditorFontSize
        self.defaultEditorFontFamily = defaultEditorFontFamily
        self.defaultEditorTheme = defaultEditorTheme
        self.fontLigatureOverrides = fontLigatureOverrides
        self.lastCustomEditorFontFamily = lastCustomEditorFontFamily
        self.defaultEditorPaletteIDLight = defaultEditorPaletteIDLight
        self.defaultEditorPaletteIDDark = defaultEditorPaletteIDDark
        self.customEditorPalettes = customEditorPalettes
        self.customThemes = customThemes
        self.defaultEditorLineHeight = defaultEditorLineHeight
        self.editorShowLineNumbers = editorShowLineNumbers
        self.editorHighlightSelectedSymbol = editorHighlightSelectedSymbol
        self.editorHighlightDelay = editorHighlightDelay
        self.editorWrapLines = editorWrapLines
        self.editorIndentWrappedLines = editorIndentWrappedLines
        self.editorEnableAutocomplete = editorEnableAutocomplete
        self.useServerColorAsAccent = useServerColorAsAccent
        self.themeTabs = themeTabs
        self.themeResultsGrid = themeResultsGrid
        self.resultsAlternateRowShading = resultsAlternateRowShading
        self.foreignKeyDisplayMode = foreignKeyDisplayMode
        self.foreignKeyInspectorBehavior = foreignKeyInspectorBehavior
        self.foreignKeyIncludeRelated = foreignKeyIncludeRelated
        self.resultsInitialRowLimit = resultsInitialRowLimit
        self.resultsPreviewBatchSize = resultsPreviewBatchSize
        self.resultSpoolMaxBytes = resultSpoolMaxBytes
        self.resultSpoolRetentionHours = resultSpoolRetentionHours
        self.resultSpoolCustomLocation = resultSpoolCustomLocation
        self.inspectorWidth = inspectorWidth
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
        self.activeThemeIDLight = activeThemeIDLight
        self.activeThemeIDDark = activeThemeIDDark
        self.keepTabsInMemory = keepTabsInMemory
    }

    enum CodingKeys: String, CodingKey {
        case appearanceMode
        case defaultEditorFontSize
        case defaultEditorFontFamily
        case defaultEditorTheme
        case fontLigatureOverrides
        case defaultEditorPaletteID // Legacy single-mode palette
        case defaultEditorPaletteIDLight
        case defaultEditorPaletteIDDark
        case lastCustomEditorFontFamily
        case customEditorPalettes
        case customThemes
        case defaultEditorLineHeight
        case editorShowLineNumbers
        case editorHighlightSelectedSymbol
        case editorHighlightDelay
        case editorWrapLines
        case editorIndentWrappedLines
        case editorEnableAutocomplete
        case useServerColorAsAccent
        case defaultWindowWidth
        case defaultWindowHeight
        case activeThemeIDLight
        case activeThemeIDDark
        case themeTabs
        case themeResultsGrid
        case resultsAlternateRowShading
        case foreignKeyDisplayMode
        case foreignKeyInspectorBehavior
        case foreignKeyIncludeRelated
        case resultsInitialRowLimit
        case resultsPreviewBatchSize
        case resultSpoolMaxBytes
        case resultSpoolRetentionHours
        case resultSpoolCustomLocation
        case inspectorWidth
        case keepTabsInMemory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? 12.0
        defaultEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .defaultEditorFontFamily) ?? "JetBrainsMono-Regular"
        defaultEditorTheme = try container.decodeIfPresent(String.self, forKey: .defaultEditorTheme) ?? SQLEditorPalette.aurora.id
        fontLigatureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .fontLigatureOverrides) ?? [:]
        lastCustomEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .lastCustomEditorFontFamily)

        if let palettes = try container.decodeIfPresent([SQLEditorTokenPalette].self, forKey: .customEditorPalettes) {
            customEditorPalettes = palettes
        } else if let legacyPalettes = try container.decodeIfPresent([SQLEditorPalette].self, forKey: .customEditorPalettes) {
            customEditorPalettes = legacyPalettes.map { SQLEditorTokenPalette(from: $0) }
        } else {
            customEditorPalettes = []
        }

        customThemes = try container.decodeIfPresent([AppColorTheme].self, forKey: .customThemes) ?? []

        let legacyPaletteID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteID)
        let decodedLightID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDLight)
        let decodedDarkID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDDark)

        let customPalettes = customEditorPalettes
        func palette(for id: String) -> SQLEditorTokenPalette? {
            customPalettes.first(where: { $0.id == id }) ?? SQLEditorTokenPalette.builtIn.first(where: { $0.id == id })
        }

        let fallbackID = legacyPaletteID ?? SQLEditorPalette.aurora.id
        let fallbackPalette = palette(for: fallbackID)

        defaultEditorPaletteIDLight = decodedLightID
            ?? (fallbackPalette?.tone == .light ? fallbackID : (SQLEditorTokenPalette.builtIn.first { $0.tone == .light }?.id ?? SQLEditorPalette.aurora.id))

        defaultEditorPaletteIDDark = decodedDarkID
            ?? (fallbackPalette?.tone == .dark ? fallbackID : (SQLEditorTokenPalette.builtIn.first { $0.tone == .dark }?.id ?? SQLEditorPalette.midnight.id))

        defaultEditorLineHeight = try container.decodeIfPresent(Double.self, forKey: .defaultEditorLineHeight) ?? Double(SQLEditorTheme.defaultLineHeight)
        editorShowLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .editorShowLineNumbers) ?? true
        editorHighlightSelectedSymbol = try container.decodeIfPresent(Bool.self, forKey: .editorHighlightSelectedSymbol) ?? true
        editorHighlightDelay = try container.decodeIfPresent(Double.self, forKey: .editorHighlightDelay) ?? 0.25
        editorWrapLines = try container.decodeIfPresent(Bool.self, forKey: .editorWrapLines) ?? true
        editorIndentWrappedLines = try container.decodeIfPresent(Int.self, forKey: .editorIndentWrappedLines) ?? 4
        editorEnableAutocomplete = try container.decodeIfPresent(Bool.self, forKey: .editorEnableAutocomplete) ?? true
        useServerColorAsAccent = try container.decodeIfPresent(Bool.self, forKey: .useServerColorAsAccent) ?? true
        defaultWindowWidth = try container.decodeIfPresent(Double.self, forKey: .defaultWindowWidth)
        defaultWindowHeight = try container.decodeIfPresent(Double.self, forKey: .defaultWindowHeight)
        activeThemeIDLight = try container.decodeIfPresent(AppColorTheme.ID.self, forKey: .activeThemeIDLight)
        activeThemeIDDark = try container.decodeIfPresent(AppColorTheme.ID.self, forKey: .activeThemeIDDark)
        themeTabs = try container.decodeIfPresent(Bool.self, forKey: .themeTabs) ?? false
        themeResultsGrid = try container.decodeIfPresent(Bool.self, forKey: .themeResultsGrid) ?? true
        resultsAlternateRowShading = try container.decodeIfPresent(Bool.self, forKey: .resultsAlternateRowShading) ?? false
        foreignKeyDisplayMode = try container.decodeIfPresent(ForeignKeyDisplayMode.self, forKey: .foreignKeyDisplayMode) ?? .showInspector
        foreignKeyInspectorBehavior = try container.decodeIfPresent(ForeignKeyInspectorBehavior.self, forKey: .foreignKeyInspectorBehavior) ?? .respectInspectorVisibility
        foreignKeyIncludeRelated = try container.decodeIfPresent(Bool.self, forKey: .foreignKeyIncludeRelated) ?? false
        resultsInitialRowLimit = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsInitialRowLimit) ?? 500)
        resultsPreviewBatchSize = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsPreviewBatchSize) ?? 500)
        inspectorWidth = try container.decodeIfPresent(Double.self, forKey: .inspectorWidth)
        keepTabsInMemory = try container.decodeIfPresent(Bool.self, forKey: .keepTabsInMemory) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(defaultEditorFontSize, forKey: .defaultEditorFontSize)
        try container.encode(defaultEditorFontFamily, forKey: .defaultEditorFontFamily)
        try container.encode(defaultEditorTheme, forKey: .defaultEditorTheme)
        try container.encode(fontLigatureOverrides, forKey: .fontLigatureOverrides)
        try container.encodeIfPresent(lastCustomEditorFontFamily, forKey: .lastCustomEditorFontFamily)
        try container.encode(customEditorPalettes, forKey: .customEditorPalettes)
        try container.encode(customThemes, forKey: .customThemes)
        try container.encode(defaultEditorLineHeight, forKey: .defaultEditorLineHeight)
        try container.encode(editorShowLineNumbers, forKey: .editorShowLineNumbers)
        try container.encode(editorHighlightSelectedSymbol, forKey: .editorHighlightSelectedSymbol)
        try container.encode(editorHighlightDelay, forKey: .editorHighlightDelay)
        try container.encode(editorWrapLines, forKey: .editorWrapLines)
        try container.encode(editorIndentWrappedLines, forKey: .editorIndentWrappedLines)
        try container.encode(editorEnableAutocomplete, forKey: .editorEnableAutocomplete)
        try container.encode(useServerColorAsAccent, forKey: .useServerColorAsAccent)
        try container.encode(defaultWindowWidth, forKey: .defaultWindowWidth)
        try container.encode(defaultWindowHeight, forKey: .defaultWindowHeight)
        try container.encodeIfPresent(activeThemeIDLight, forKey: .activeThemeIDLight)
        try container.encodeIfPresent(activeThemeIDDark, forKey: .activeThemeIDDark)
        try container.encode(themeTabs, forKey: .themeTabs)
        try container.encode(themeResultsGrid, forKey: .themeResultsGrid)
        try container.encode(resultsAlternateRowShading, forKey: .resultsAlternateRowShading)
        try container.encode(foreignKeyDisplayMode, forKey: .foreignKeyDisplayMode)
        try container.encode(foreignKeyInspectorBehavior, forKey: .foreignKeyInspectorBehavior)
        try container.encode(foreignKeyIncludeRelated, forKey: .foreignKeyIncludeRelated)
        try container.encode(resultsInitialRowLimit, forKey: .resultsInitialRowLimit)
        try container.encode(resultsPreviewBatchSize, forKey: .resultsPreviewBatchSize)
        try container.encode(resultSpoolMaxBytes, forKey: .resultSpoolMaxBytes)
        try container.encode(resultSpoolRetentionHours, forKey: .resultSpoolRetentionHours)
        try container.encodeIfPresent(resultSpoolCustomLocation, forKey: .resultSpoolCustomLocation)
        try container.encodeIfPresent(inspectorWidth, forKey: .inspectorWidth)
        try container.encode(keepTabsInMemory, forKey: .keepTabsInMemory)

        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteIDLight)
        try container.encode(defaultEditorPaletteIDDark, forKey: .defaultEditorPaletteIDDark)

        // Persist the legacy field so older builds can still read a sensible default.
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteID)
    }
}

enum AppearanceMode: String, Codable, CaseIterable {
    case light
    case dark
    case system

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// MARK: - Project Export/Import Models

struct ProjectExportData: Codable {
    let project: Project
    let connections: [SavedConnection]
    let identities: [SavedIdentity]
    let folders: [SavedFolder]
    let globalSettings: GlobalSettings?
    let clipboardHistory: [ClipboardHistoryStore.Entry]?
    let bookmarks: [Bookmark]
    let exportedAt: Date
    let version: String

    init(
        project: Project,
        connections: [SavedConnection],
        identities: [SavedIdentity],
        folders: [SavedFolder],
        globalSettings: GlobalSettings?,
        clipboardHistory: [ClipboardHistoryStore.Entry]? = nil,
        bookmarks: [Bookmark] = [],
        exportedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.project = project
        self.connections = connections
        self.identities = identities
        self.folders = folders
        self.globalSettings = globalSettings
        self.clipboardHistory = clipboardHistory
        self.bookmarks = bookmarks
        self.exportedAt = exportedAt
        self.version = version
    }
}
