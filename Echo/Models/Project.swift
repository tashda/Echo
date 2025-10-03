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


    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        colorHex: String = "",
        iconName: String? = nil,
        isDefault: Bool = false,
        settings: ProjectSettings = ProjectSettings()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.colorHex = colorHex
        self.iconName = iconName
        self.isDefault = isDefault
        self.settings = settings
    }

    static let defaultProject = Project(
        name: "Default",
        colorHex: "007AFF",
        isDefault: true
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
}

// MARK: - Global Settings

struct GlobalSettings: Codable, Hashable {
    // Global UI preferences
    var appearanceMode: AppearanceMode
    var defaultEditorFontSize: Double
    var defaultEditorFontFamily: String
    var defaultEditorTheme: String // Legacy identifier kept for backward compatibility
    var defaultEditorPaletteID: String
    var customEditorPalettes: [SQLEditorPalette]
    var defaultEditorLineHeight: Double
    var editorShowLineNumbers: Bool = true
    var editorHighlightSelectedSymbol: Bool = true
    var editorHighlightDelay: Double = 0.25
    var editorWrapLines: Bool = true
    var editorIndentWrappedLines: Int = 4
    var useServerColorAsAccent: Bool

    // Window preferences
    var defaultWindowWidth: Double?
    var defaultWindowHeight: Double?

    init(
        appearanceMode: AppearanceMode = .system,
        defaultEditorFontSize: Double = 12.0,
        defaultEditorFontFamily: String = "JetBrainsMono-Regular",
        defaultEditorTheme: String = SQLEditorPalette.aurora.id,
        defaultEditorPaletteID: String = SQLEditorPalette.aurora.id,
        customEditorPalettes: [SQLEditorPalette] = [],
        defaultEditorLineHeight: Double = Double(SQLEditorTheme.defaultLineHeight),
        editorShowLineNumbers: Bool = true,
        editorHighlightSelectedSymbol: Bool = true,
        editorHighlightDelay: Double = 0.25,
        editorWrapLines: Bool = true,
        editorIndentWrappedLines: Int = 4,
        useServerColorAsAccent: Bool = true,
        defaultWindowWidth: Double? = nil,
        defaultWindowHeight: Double? = nil
    ) {
        self.appearanceMode = appearanceMode
        self.defaultEditorFontSize = defaultEditorFontSize
        self.defaultEditorFontFamily = defaultEditorFontFamily
        self.defaultEditorTheme = defaultEditorTheme
        self.defaultEditorPaletteID = defaultEditorPaletteID
        self.customEditorPalettes = customEditorPalettes
        self.defaultEditorLineHeight = defaultEditorLineHeight
        self.editorShowLineNumbers = editorShowLineNumbers
        self.editorHighlightSelectedSymbol = editorHighlightSelectedSymbol
        self.editorHighlightDelay = editorHighlightDelay
        self.editorWrapLines = editorWrapLines
        self.editorIndentWrappedLines = editorIndentWrappedLines
        self.useServerColorAsAccent = useServerColorAsAccent
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
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
    let exportedAt: Date
    let version: String

    init(
        project: Project,
        connections: [SavedConnection],
        identities: [SavedIdentity],
        folders: [SavedFolder],
        globalSettings: GlobalSettings?,
        clipboardHistory: [ClipboardHistoryStore.Entry]? = nil,
        exportedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.project = project
        self.connections = connections
        self.identities = identities
        self.folders = folders
        self.globalSettings = globalSettings
        self.clipboardHistory = clipboardHistory
        self.exportedAt = exportedAt
        self.version = version
    }
}
