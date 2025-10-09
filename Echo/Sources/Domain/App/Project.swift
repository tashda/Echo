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

        let fallbackTheme = AppColorTheme.fallbackTheme(for: tone, defaultPaletteID: defaultPaletteID)

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
                palette.tokens.keyword,
                palette.tokens.string,
                palette.tokens.operatorSymbol,
                palette.tokens.identifier,
                palette.tokens.comment
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
            return palette.tokens.keyword
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
            accent: palette.tokens.keyword,
            swatchColors: [
                palette.tokens.keyword,
                palette.tokens.string,
                palette.tokens.operatorSymbol,
                palette.tokens.identifier,
                palette.tokens.comment
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

    static func builtIn(
        identifier: String,
        name: String,
        tone: SQLEditorPalette.Tone,
        paletteID: String,
        accent: ColorRepresentable?,
        swatchColors: [ColorRepresentable]
    ) -> AppColorTheme {
        var theme = AppColorTheme.fromPalette(
            tone == .dark ? SQLEditorPalette.midnight : SQLEditorPalette.aurora,
            idOverride: "builtin-\(identifier)-\(tone.rawValue)",
            isCustom: false
        )
        theme.name = name
        theme.tone = tone
        theme.defaultPaletteID = paletteID
        theme.accent = accent
        theme.swatchColors = swatchColors
        return theme
    }
}

private struct BuiltInThemeDefinition {
    let identifier: String
    let name: String
    let tone: SQLEditorPalette.Tone
    let accent: ColorRepresentable
    let swatches: [ColorRepresentable]
}

extension AppColorTheme {
    private static let builtInThemeCatalog: [BuiltInThemeDefinition] = [
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Sky",
            tone: .light,
            accent: ColorRepresentable(hex: 0x3B82F6),
            swatches: [
                ColorRepresentable(hex: 0x3B82F6),
                ColorRepresentable(hex: 0x0EA5E9),
                ColorRepresentable(hex: 0x10B981),
                ColorRepresentable(hex: 0xF97316),
                ColorRepresentable(hex: 0x64748B)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "sunrise",
            name: "Sunrise",
            tone: .light,
            accent: ColorRepresentable(hex: 0xF97316),
            swatches: [
                ColorRepresentable(hex: 0xF97316),
                ColorRepresentable(hex: 0xFB923C),
                ColorRepresentable(hex: 0xFACC15),
                ColorRepresentable(hex: 0xDC2626),
                ColorRepresentable(hex: 0x78350F)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "meadow",
            name: "Meadow",
            tone: .light,
            accent: ColorRepresentable(hex: 0x16A34A),
            swatches: [
                ColorRepresentable(hex: 0x16A34A),
                ColorRepresentable(hex: 0x65A30D),
                ColorRepresentable(hex: 0x0EA5E9),
                ColorRepresentable(hex: 0x4ADE80),
                ColorRepresentable(hex: 0x15803D)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "slate",
            name: "Slate",
            tone: .light,
            accent: ColorRepresentable(hex: 0x475569),
            swatches: [
                ColorRepresentable(hex: 0x475569),
                ColorRepresentable(hex: 0x64748B),
                ColorRepresentable(hex: 0x1E293B),
                ColorRepresentable(hex: 0x0F172A),
                ColorRepresentable(hex: 0x94A3B8)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "default",
            name: "Midnight",
            tone: .dark,
            accent: ColorRepresentable(hex: 0x38BDF8),
            swatches: [
                ColorRepresentable(hex: 0x38BDF8),
                ColorRepresentable(hex: 0x2563EB),
                ColorRepresentable(hex: 0x8B5CF6),
                ColorRepresentable(hex: 0x0EA5E9),
                ColorRepresentable(hex: 0x1E40AF)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "neon",
            name: "Neon",
            tone: .dark,
            accent: ColorRepresentable(hex: 0xA855F7),
            swatches: [
                ColorRepresentable(hex: 0xA855F7),
                ColorRepresentable(hex: 0xEC4899),
                ColorRepresentable(hex: 0x22D3EE),
                ColorRepresentable(hex: 0xF97316),
                ColorRepresentable(hex: 0x4C1D95)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "aurora",
            name: "Aurora",
            tone: .dark,
            accent: ColorRepresentable(hex: 0x34D399),
            swatches: [
                ColorRepresentable(hex: 0x34D399),
                ColorRepresentable(hex: 0x14B8A6),
                ColorRepresentable(hex: 0x8B5CF6),
                ColorRepresentable(hex: 0xFBBF24),
                ColorRepresentable(hex: 0x22C55E)
            ]
        ),
        BuiltInThemeDefinition(
            identifier: "carbon",
            name: "Carbon",
            tone: .dark,
            accent: ColorRepresentable(hex: 0x94A3B8),
            swatches: [
                ColorRepresentable(hex: 0x94A3B8),
                ColorRepresentable(hex: 0x6366F1),
                ColorRepresentable(hex: 0x4F46E5),
                ColorRepresentable(hex: 0x1F2937),
                ColorRepresentable(hex: 0x6B7280)
            ]
        )
    ]

    static func builtInThemes(for tone: SQLEditorPalette.Tone) -> [AppColorTheme] {
        let fallbackPaletteID = tone == .light ? SQLEditorPalette.aurora.id : SQLEditorPalette.midnight.id
        return builtInThemeCatalog
            .filter { $0.tone == tone }
            .map {
                AppColorTheme.builtIn(
                    identifier: $0.identifier,
                    name: $0.name,
                    tone: tone,
                    paletteID: fallbackPaletteID,
                    accent: $0.accent,
                    swatchColors: $0.swatches
                )
            }
    }

    static func fallbackTheme(for tone: SQLEditorPalette.Tone, defaultPaletteID: String) -> AppColorTheme {
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
        return (builtIn + customs).sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

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

struct GlobalSettings: Codable, Hashable {
    // Global UI preferences
    var appearanceMode: AppearanceMode
    var defaultEditorFontSize: Double
    var defaultEditorFontFamily: String
    var defaultEditorTheme: String // Legacy identifier kept for backward compatibility
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

    // Window preferences
    var defaultWindowWidth: Double?
    var defaultWindowHeight: Double?

    init(
        appearanceMode: AppearanceMode = .system,
        defaultEditorFontSize: Double = 12.0,
        defaultEditorFontFamily: String = "JetBrainsMono-Regular",
        defaultEditorTheme: String = SQLEditorPalette.aurora.id,
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
        defaultWindowWidth: Double? = nil,
        defaultWindowHeight: Double? = nil,
        activeThemeIDLight: AppColorTheme.ID? = nil,
        activeThemeIDDark: AppColorTheme.ID? = nil
    ) {
        self.appearanceMode = appearanceMode
        self.defaultEditorFontSize = defaultEditorFontSize
        self.defaultEditorFontFamily = defaultEditorFontFamily
        self.defaultEditorTheme = defaultEditorTheme
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
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
        self.activeThemeIDLight = activeThemeIDLight
        self.activeThemeIDDark = activeThemeIDDark
    }

    enum CodingKeys: String, CodingKey {
        case appearanceMode
        case defaultEditorFontSize
        case defaultEditorFontFamily
        case defaultEditorTheme
        case defaultEditorPaletteID // Legacy single-mode palette
        case defaultEditorPaletteIDLight
        case defaultEditorPaletteIDDark
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? 12.0
        defaultEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .defaultEditorFontFamily) ?? "JetBrainsMono-Regular"
        defaultEditorTheme = try container.decodeIfPresent(String.self, forKey: .defaultEditorTheme) ?? SQLEditorPalette.aurora.id

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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(defaultEditorFontSize, forKey: .defaultEditorFontSize)
        try container.encode(defaultEditorFontFamily, forKey: .defaultEditorFontFamily)
        try container.encode(defaultEditorTheme, forKey: .defaultEditorTheme)
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
