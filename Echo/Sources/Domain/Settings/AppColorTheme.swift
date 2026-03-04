import Foundation
import SwiftUI
import Combine
import EchoSense

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
