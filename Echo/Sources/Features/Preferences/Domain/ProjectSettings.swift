import Foundation
import EchoSense

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
    var accentColorSource: AccentColorSource?
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
        accentColorSource: AccentColorSource? = nil,
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
        self.accentColorSource = accentColorSource
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
        case accentColorSource
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
        accentColorSource = try container.decodeIfPresent(AccentColorSource.self, forKey: .accentColorSource)
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
        try container.encodeIfPresent(accentColorSource, forKey: .accentColorSource)
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
