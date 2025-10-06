import Foundation
import SwiftUI
import Combine
#if canImport(AppKit)
import AppKit
#endif

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
    var customEditorPalette: SQLEditorPalette?
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
        customEditorPalette: SQLEditorPalette? = nil,
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

    var availablePalettes: [SQLEditorPalette] {
        var combined = SQLEditorPalette.builtIn
        for palette in customEditorPalettes where !combined.contains(where: { $0.id == palette.id }) {
            combined.append(palette)
        }
        return combined
    }

    func palette(withID id: String) -> SQLEditorPalette? {
        if let custom = customEditorPalettes.first(where: { $0.id == id }) {
            return custom
        }
        return SQLEditorPalette.builtIn.first(where: { $0.id == id })
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

    func defaultPalette(for tone: SQLEditorPalette.Tone) -> SQLEditorPalette? {
        palette(withID: defaultPaletteID(for: tone))
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
    var customEditorPalettes: [SQLEditorPalette]
    var defaultEditorLineHeight: Double
    var editorShowLineNumbers: Bool = true
    var editorHighlightSelectedSymbol: Bool = true
    var editorHighlightDelay: Double = 0.25
    var editorWrapLines: Bool = true
    var editorIndentWrappedLines: Int = 4
    var editorEnableAutocomplete: Bool = true
    var useServerColorAsAccent: Bool

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
        customEditorPalettes: [SQLEditorPalette] = [],
        defaultEditorLineHeight: Double = Double(SQLEditorTheme.defaultLineHeight),
        editorShowLineNumbers: Bool = true,
        editorHighlightSelectedSymbol: Bool = true,
        editorHighlightDelay: Double = 0.25,
        editorWrapLines: Bool = true,
        editorIndentWrappedLines: Int = 4,
        editorEnableAutocomplete: Bool = true,
        useServerColorAsAccent: Bool = true,
        defaultWindowWidth: Double? = nil,
        defaultWindowHeight: Double? = nil
    ) {
        self.appearanceMode = appearanceMode
        self.defaultEditorFontSize = defaultEditorFontSize
        self.defaultEditorFontFamily = defaultEditorFontFamily
        self.defaultEditorTheme = defaultEditorTheme
        self.defaultEditorPaletteIDLight = defaultEditorPaletteIDLight
        self.defaultEditorPaletteIDDark = defaultEditorPaletteIDDark
        self.customEditorPalettes = customEditorPalettes
        self.defaultEditorLineHeight = defaultEditorLineHeight
        self.editorShowLineNumbers = editorShowLineNumbers
        self.editorHighlightSelectedSymbol = editorHighlightSelectedSymbol
        self.editorHighlightDelay = editorHighlightDelay
        self.editorWrapLines = editorWrapLines
        self.editorIndentWrappedLines = editorIndentWrappedLines
        self.editorEnableAutocomplete = editorEnableAutocomplete
        self.useServerColorAsAccent = useServerColorAsAccent
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? 12.0
        defaultEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .defaultEditorFontFamily) ?? "JetBrainsMono-Regular"
        defaultEditorTheme = try container.decodeIfPresent(String.self, forKey: .defaultEditorTheme) ?? SQLEditorPalette.aurora.id

        let decodedCustomPalettes = try container.decodeIfPresent([SQLEditorPalette].self, forKey: .customEditorPalettes) ?? []

        customEditorPalettes = decodedCustomPalettes

        let legacyPaletteID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteID)
        let decodedLightID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDLight)
        let decodedDarkID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDDark)

        func palette(for id: String) -> SQLEditorPalette? {
            decodedCustomPalettes.first(where: { $0.id == id }) ?? SQLEditorPalette.builtIn.first(where: { $0.id == id })
        }

        let fallbackID = legacyPaletteID ?? SQLEditorPalette.aurora.id
        let fallbackPalette = palette(for: fallbackID)

        defaultEditorPaletteIDLight = decodedLightID
            ?? (fallbackPalette?.isDark == false ? fallbackID : SQLEditorPalette.aurora.id)

        defaultEditorPaletteIDDark = decodedDarkID
            ?? (fallbackPalette?.isDark == true ? fallbackID : SQLEditorPalette.midnight.id)

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
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(defaultEditorFontSize, forKey: .defaultEditorFontSize)
        try container.encode(defaultEditorFontFamily, forKey: .defaultEditorFontFamily)
        try container.encode(defaultEditorTheme, forKey: .defaultEditorTheme)
        try container.encode(customEditorPalettes, forKey: .customEditorPalettes)
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
