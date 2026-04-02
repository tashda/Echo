import Foundation
import SwiftUI
import EchoSense

enum AccentColorSource: String, Codable, Hashable, CaseIterable {
    case system
    case connection
    case custom

    var displayName: String {
        switch self {
        case .system: return "System"
        case .connection: return "Connection"
        case .custom: return "Custom"
        }
    }
}

enum NativePsqlRuntimePreference: String, Codable, Hashable, CaseIterable {
    case bundled
    case system

    var displayName: String {
        switch self {
        case .bundled: return "Bundled Binary"
        case .system: return "System Binary"
        }
    }
}

enum SidebarAutoExpandSection: String, Codable, Hashable, CaseIterable, Identifiable {
    case databases
    case tables
    case views
    case materializedViews
    case functions
    case procedures
    case triggers
    case management
    case security

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .databases: return "Databases"
        case .tables: return "Tables"
        case .views: return "Views"
        case .materializedViews: return "Materialized Views"
        case .functions: return "Functions"
        case .procedures: return "Procedures"
        case .triggers: return "Triggers"
        case .management: return "Management"
        case .security: return "Security"
        }
    }

    var objectType: SchemaObjectInfo.ObjectType? {
        switch self {
        case .tables: return .table
        case .views: return .view
        case .materializedViews: return .materializedView
        case .functions: return .function
        case .procedures: return .procedure
        case .triggers: return .trigger
        case .databases, .management, .security: return nil
        }
    }

    /// Sections common to all database types.
    static let generalSections: [SidebarAutoExpandSection] = [
        .databases, .tables, .views, .functions, .triggers
    ]

    /// Sections unique to a specific database type (not in generalSections).
    static func uniqueSections(for databaseType: DatabaseType) -> [SidebarAutoExpandSection] {
        switch databaseType {
        case .postgresql: return [.materializedViews, .security]
        case .microsoftSQL: return [.procedures, .management, .security]
        case .mysql: return [.procedures]
        case .sqlite: return []
        }
    }

    /// All sections relevant for a given database type.
    static func allSections(for databaseType: DatabaseType) -> [SidebarAutoExpandSection] {
        let supported = Set(SchemaObjectInfo.ObjectType.supported(for: databaseType))
        let general = generalSections.filter { section in
            guard let objectType = section.objectType else { return true } // .databases
            return supported.contains(objectType)
        }
        return general + uniqueSections(for: databaseType)
    }
}

struct ResultGridColorOverrides: Codable, Hashable {
    var nullHex: String?
    var numericHex: String?
    var booleanHex: String?
    var temporalHex: String?
    var binaryHex: String?
    var identifierHex: String?
    var jsonHex: String?
    var textHex: String?
}

enum ToolbarProjectButtonStyle: String, Codable, Hashable, CaseIterable {
    case account
    case projectIcon

    var displayName: String {
        switch self {
        case .account: return "Account"
        case .projectIcon: return "Project Icon"
        }
    }
}

struct GlobalSettings: Codable, Hashable {
    var appearanceMode: AppearanceMode
    var defaultEditorFontSize: Double
    var defaultEditorFontFamily: String
    var defaultEditorTheme: String
    var fontLigatureOverrides: [String: Bool]
    var defaultEditorPaletteIDLight: String
    var defaultEditorPaletteIDDark: String
    var customEditorPalettes: [SQLEditorTokenPalette]
    var defaultEditorLineHeight: Double
    var editorShowLineNumbers: Bool = true
    var editorHighlightSelectedSymbol: Bool = true
    var editorHighlightDelay: Double = 0.25
    var editorWrapLines: Bool = true
    var editorIndentWrappedLines: Int = 4
    var editorEnableAutocomplete: Bool = true
    var editorQualifyTableCompletions: Bool = false
    var editorShowSystemSchemas: Bool = false
    var editorEnableLiveValidation: Bool = true
    var accentColorSource: AccentColorSource
    var customAccentColorHex: String?
    var workspaceTabBarStyle: WorkspaceTabBarStyle = .floating
    var tabOverviewStyle: TabOverviewStyle = .comfortable
    var resultsAlternateRowShading: Bool = false
    var resultsShowRowNumbers: Bool = true
    var resultGridColorOverrides: ResultGridColorOverrides = .init()
    var showForeignKeysInInspector: Bool = true
    var showJsonInInspector: Bool = true
    var resultsInitialRowLimit: Int = 500
    var resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024
    var resultSpoolRetentionHours: Int = 72
    var resultSpoolCustomLocation: String?
    var autoOpenInspectorOnSelection: Bool = true
    var autoOpenBottomPanel: Bool = true
    var diagramPrefetchMode: DiagramPrefetchMode = .off
    var diagramRefreshCadence: DiagramRefreshCadence = .never
    var diagramCacheMaxBytes: Int = 512 * 1_024 * 1_024
    var diagramVerifyBeforeRefresh: Bool = true
    var diagramRenderRelationshipsForLargeDiagrams: Bool = true
    var diagramUseThemedAppearance: Bool = true
    var customKeyboardShortcuts: [String: CustomShortcutBinding]?
    var sidebarAutoExpandSections: Set<SidebarAutoExpandSection> = [.databases]
    var sidebarCustomizePerDatabaseType: Bool = false
    var sidebarAutoExpandPostgresql: Set<SidebarAutoExpandSection>?
    var sidebarAutoExpandSQLServer: Set<SidebarAutoExpandSection>?
    var sidebarAutoExpandMySQL: Set<SidebarAutoExpandSection>?
    var managedPostgresConsoleEnabled: Bool = true
    var nativePsqlEnabled: Bool = false
    var nativePsqlRuntimePreference: NativePsqlRuntimePreference = .bundled
    var nativePsqlAllowSystemBinaryFallback: Bool = false
    var nativePsqlAllowShellEscape: Bool = true
    var nativePsqlAllowFileCommands: Bool = true
    var pgToolCustomPath: String?
    var mysqlToolCustomPath: String?
    var sidebarIconColorMode: SidebarIconColorMode = .colorful
    var sidebarDensity: SidebarDensity = .medium
    var toolbarProjectButtonStyle: ToolbarProjectButtonStyle = .account
    var activityMonitorRefreshInterval: Double = 5.0
    var hideInaccessibleDatabases: Bool = false
    var searchIncludeOfflineDatabases: Bool = false
    var searchMinimumQueryLength: Int = 2
    var searchDefaultCategories: Set<String>?
    var notificationPreferences: NotificationPreferences = NotificationPreferences()

    /// Returns the effective auto-expand sections for a given database type.
    func sidebarExpandSections(for databaseType: DatabaseType) -> Set<SidebarAutoExpandSection> {
        if sidebarCustomizePerDatabaseType {
            switch databaseType {
            case .postgresql: if let override = sidebarAutoExpandPostgresql { return override }
            case .microsoftSQL: if let override = sidebarAutoExpandSQLServer { return override }
            case .mysql: if let override = sidebarAutoExpandMySQL { return override }
            case .sqlite: break
            }
        }
        // Fall back to general, filtered to sections relevant for this type
        let relevant = Set(SidebarAutoExpandSection.allSections(for: databaseType))
        return sidebarAutoExpandSections.intersection(relevant)
    }

    init(
        appearanceMode: AppearanceMode = .system,
        defaultEditorFontSize: Double = 12.0,
        defaultEditorFontFamily: String = "JetBrainsMono-Regular",
        defaultEditorTheme: String = SQLEditorPalette.aurora.id,
        fontLigatureOverrides: [String: Bool] = [:],
        defaultEditorPaletteIDLight: String = SQLEditorPalette.aurora.id,
        defaultEditorPaletteIDDark: String = SQLEditorPalette.midnight.id,
        customEditorPalettes: [SQLEditorTokenPalette] = [],
        defaultEditorLineHeight: Double = Double(SQLEditorTheme.defaultLineHeight),
        accentColorSource: AccentColorSource = .connection
    ) {
        self.appearanceMode = appearanceMode
        self.defaultEditorFontSize = defaultEditorFontSize
        self.defaultEditorFontFamily = defaultEditorFontFamily
        self.defaultEditorTheme = defaultEditorTheme
        self.fontLigatureOverrides = fontLigatureOverrides
        self.defaultEditorPaletteIDLight = defaultEditorPaletteIDLight
        self.defaultEditorPaletteIDDark = defaultEditorPaletteIDDark
        self.customEditorPalettes = customEditorPalettes
        self.defaultEditorLineHeight = defaultEditorLineHeight
        self.accentColorSource = accentColorSource
    }

    enum CodingKeys: String, CodingKey {
        case appearanceMode, defaultEditorFontSize, defaultEditorFontFamily, defaultEditorTheme
        case fontLigatureOverrides, defaultEditorPaletteID, defaultEditorPaletteIDLight, defaultEditorPaletteIDDark
        case customEditorPalettes, defaultEditorLineHeight
        case editorShowLineNumbers, editorHighlightSelectedSymbol, editorHighlightDelay
        case editorWrapLines, editorIndentWrappedLines, editorEnableAutocomplete
        case editorQualifyTableCompletions, editorShowSystemSchemas
        case editorEnableLiveValidation
        case useServerColorAsAccent, accentColorSource, customAccentColorHex
        case workspaceTabBarStyle, tabOverviewStyle
        case resultsAlternateRowShading, resultsShowRowNumbers, resultGridColorOverrides
        case showForeignKeysInInspector, showJsonInInspector
        case resultsInitialRowLimit
        case resultSpoolMaxBytes, resultSpoolRetentionHours, resultSpoolCustomLocation
        case autoOpenInspectorOnSelection, autoOpenBottomPanel
        case diagramPrefetchMode, diagramRefreshCadence, diagramCacheMaxBytes
        case diagramVerifyBeforeRefresh, diagramRenderRelationshipsForLargeDiagrams, diagramUseThemedAppearance
        case customKeyboardShortcuts
        case sidebarAutoExpandSections, sidebarCustomizePerDatabaseType
        case sidebarAutoExpandPostgresql, sidebarAutoExpandSQLServer, sidebarAutoExpandMySQL
        case managedPostgresConsoleEnabled
        case nativePsqlEnabled
        case nativePsqlRuntimePreference
        case nativePsqlAllowSystemBinaryFallback
        case nativePsqlAllowShellEscape
        case nativePsqlAllowFileCommands
        case pgToolCustomPath
        case mysqlToolCustomPath
        case sidebarIconColorMode
        case sidebarDensity
        case sidebarColoredIcons
        case activityMonitorRefreshInterval
        case hideInaccessibleDatabases
        case searchIncludeOfflineDatabases
        case searchMinimumQueryLength
        case searchDefaultCategories
        case notificationPreferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? 12.0
        defaultEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .defaultEditorFontFamily) ?? "JetBrainsMono-Regular"
        defaultEditorTheme = try container.decodeIfPresent(String.self, forKey: .defaultEditorTheme) ?? SQLEditorPalette.aurora.id
        fontLigatureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .fontLigatureOverrides) ?? [:]
        customEditorPalettes = (try? container.decodeIfPresent([SQLEditorTokenPalette].self, forKey: .customEditorPalettes)) ?? []
        let legacyPaletteID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteID)
        let decodedLightID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDLight)
        let decodedDarkID = try container.decodeIfPresent(String.self, forKey: .defaultEditorPaletteIDDark)
        let fallbackID = legacyPaletteID ?? SQLEditorPalette.aurora.id
        defaultEditorPaletteIDLight = decodedLightID ?? fallbackID
        defaultEditorPaletteIDDark = decodedDarkID ?? fallbackID
        defaultEditorLineHeight = try container.decodeIfPresent(Double.self, forKey: .defaultEditorLineHeight) ?? Double(SQLEditorTheme.defaultLineHeight)
        editorShowLineNumbers = try container.decodeIfPresent(Bool.self, forKey: .editorShowLineNumbers) ?? true
        editorHighlightSelectedSymbol = try container.decodeIfPresent(Bool.self, forKey: .editorHighlightSelectedSymbol) ?? true
        editorHighlightDelay = try container.decodeIfPresent(Double.self, forKey: .editorHighlightDelay) ?? 0.25
        editorWrapLines = try container.decodeIfPresent(Bool.self, forKey: .editorWrapLines) ?? true
        editorIndentWrappedLines = try container.decodeIfPresent(Int.self, forKey: .editorIndentWrappedLines) ?? 4
        editorEnableAutocomplete = try container.decodeIfPresent(Bool.self, forKey: .editorEnableAutocomplete) ?? true
        editorQualifyTableCompletions = try container.decodeIfPresent(Bool.self, forKey: .editorQualifyTableCompletions) ?? false
        editorShowSystemSchemas = try container.decodeIfPresent(Bool.self, forKey: .editorShowSystemSchemas) ?? false
        editorEnableLiveValidation = try container.decodeIfPresent(Bool.self, forKey: .editorEnableLiveValidation) ?? true
        if let source = try container.decodeIfPresent(AccentColorSource.self, forKey: .accentColorSource) {
            accentColorSource = source
        } else {
            let legacyBool = try container.decodeIfPresent(Bool.self, forKey: .useServerColorAsAccent) ?? true
            accentColorSource = legacyBool ? .connection : .system
        }
        customAccentColorHex = try container.decodeIfPresent(String.self, forKey: .customAccentColorHex)
        workspaceTabBarStyle = try container.decodeIfPresent(WorkspaceTabBarStyle.self, forKey: .workspaceTabBarStyle) ?? .floating
        tabOverviewStyle = try container.decodeIfPresent(TabOverviewStyle.self, forKey: .tabOverviewStyle) ?? .comfortable
        resultsAlternateRowShading = try container.decodeIfPresent(Bool.self, forKey: .resultsAlternateRowShading) ?? false
        resultsShowRowNumbers = try container.decodeIfPresent(Bool.self, forKey: .resultsShowRowNumbers) ?? true
        resultGridColorOverrides = try container.decodeIfPresent(ResultGridColorOverrides.self, forKey: .resultGridColorOverrides) ?? .init()
        showForeignKeysInInspector = try container.decodeIfPresent(Bool.self, forKey: .showForeignKeysInInspector) ?? true
        showJsonInInspector = try container.decodeIfPresent(Bool.self, forKey: .showJsonInInspector) ?? true
        resultsInitialRowLimit = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsInitialRowLimit) ?? 500)
        resultSpoolMaxBytes = try container.decodeIfPresent(Int.self, forKey: .resultSpoolMaxBytes) ?? 5 * 1_024 * 1_024 * 1_024
        resultSpoolRetentionHours = try container.decodeIfPresent(Int.self, forKey: .resultSpoolRetentionHours) ?? 72
        resultSpoolCustomLocation = try container.decodeIfPresent(String.self, forKey: .resultSpoolCustomLocation)
        autoOpenInspectorOnSelection = try container.decodeIfPresent(Bool.self, forKey: .autoOpenInspectorOnSelection) ?? true
        autoOpenBottomPanel = try container.decodeIfPresent(Bool.self, forKey: .autoOpenBottomPanel) ?? true
        diagramPrefetchMode = try container.decodeIfPresent(DiagramPrefetchMode.self, forKey: .diagramPrefetchMode) ?? .off
        diagramRefreshCadence = try container.decodeIfPresent(DiagramRefreshCadence.self, forKey: .diagramRefreshCadence) ?? .never
        diagramCacheMaxBytes = max(64 * 1_024 * 1_024, try container.decodeIfPresent(Int.self, forKey: .diagramCacheMaxBytes) ?? 512 * 1_024 * 1_024)
        diagramVerifyBeforeRefresh = try container.decodeIfPresent(Bool.self, forKey: .diagramVerifyBeforeRefresh) ?? true
        diagramRenderRelationshipsForLargeDiagrams = try container.decodeIfPresent(Bool.self, forKey: .diagramRenderRelationshipsForLargeDiagrams) ?? true
        diagramUseThemedAppearance = try container.decodeIfPresent(Bool.self, forKey: .diagramUseThemedAppearance) ?? true
        customKeyboardShortcuts = try container.decodeIfPresent([String: CustomShortcutBinding].self, forKey: .customKeyboardShortcuts)
        sidebarAutoExpandSections = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandSections) ?? [.databases]
        sidebarCustomizePerDatabaseType = try container.decodeIfPresent(Bool.self, forKey: .sidebarCustomizePerDatabaseType) ?? false
        sidebarAutoExpandPostgresql = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandPostgresql)
        sidebarAutoExpandSQLServer = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandSQLServer)
        sidebarAutoExpandMySQL = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandMySQL)
        managedPostgresConsoleEnabled = try container.decodeIfPresent(Bool.self, forKey: .managedPostgresConsoleEnabled) ?? true
        nativePsqlEnabled = try container.decodeIfPresent(Bool.self, forKey: .nativePsqlEnabled) ?? false
        nativePsqlRuntimePreference = try container.decodeIfPresent(NativePsqlRuntimePreference.self, forKey: .nativePsqlRuntimePreference) ?? .bundled
        nativePsqlAllowSystemBinaryFallback = try container.decodeIfPresent(Bool.self, forKey: .nativePsqlAllowSystemBinaryFallback) ?? false
        nativePsqlAllowShellEscape = try container.decodeIfPresent(Bool.self, forKey: .nativePsqlAllowShellEscape) ?? true
        nativePsqlAllowFileCommands = try container.decodeIfPresent(Bool.self, forKey: .nativePsqlAllowFileCommands) ?? true
        pgToolCustomPath = try container.decodeIfPresent(String.self, forKey: .pgToolCustomPath)
        mysqlToolCustomPath = try container.decodeIfPresent(String.self, forKey: .mysqlToolCustomPath)

        if let mode = try container.decodeIfPresent(SidebarIconColorMode.self, forKey: .sidebarIconColorMode) {
            sidebarIconColorMode = mode
        } else {
            let legacyBool = try container.decodeIfPresent(Bool.self, forKey: .sidebarColoredIcons) ?? true
            sidebarIconColorMode = legacyBool ? .colorful : .monochrome
        }
        
        // Handle migration from legacy 'default' to 'small' while transitioning to 'medium' as new default
        if let legacyString = try container.decodeIfPresent(String.self, forKey: .sidebarDensity) {
            if legacyString == "default" {
                sidebarDensity = .small
            } else {
                sidebarDensity = SidebarDensity(rawValue: legacyString) ?? .medium
            }
        } else {
            sidebarDensity = .medium
        }

        activityMonitorRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .activityMonitorRefreshInterval) ?? 5.0

        hideInaccessibleDatabases = try container.decodeIfPresent(Bool.self, forKey: .hideInaccessibleDatabases) ?? false
        searchIncludeOfflineDatabases = try container.decodeIfPresent(Bool.self, forKey: .searchIncludeOfflineDatabases) ?? false
        searchMinimumQueryLength = try container.decodeIfPresent(Int.self, forKey: .searchMinimumQueryLength) ?? 2
        searchDefaultCategories = try container.decodeIfPresent(Set<String>.self, forKey: .searchDefaultCategories)
        notificationPreferences = try container.decodeIfPresent(NotificationPreferences.self, forKey: .notificationPreferences) ?? NotificationPreferences()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(appearanceMode, forKey: .appearanceMode)
        try container.encode(defaultEditorFontSize, forKey: .defaultEditorFontSize)
        try container.encode(defaultEditorFontFamily, forKey: .defaultEditorFontFamily)
        try container.encode(defaultEditorTheme, forKey: .defaultEditorTheme)
        try container.encode(fontLigatureOverrides, forKey: .fontLigatureOverrides)
        try container.encode(customEditorPalettes, forKey: .customEditorPalettes)
        try container.encode(defaultEditorLineHeight, forKey: .defaultEditorLineHeight)
        try container.encode(editorShowLineNumbers, forKey: .editorShowLineNumbers)
        try container.encode(editorHighlightSelectedSymbol, forKey: .editorHighlightSelectedSymbol)
        try container.encode(editorHighlightDelay, forKey: .editorHighlightDelay)
        try container.encode(editorWrapLines, forKey: .editorWrapLines)
        try container.encode(editorIndentWrappedLines, forKey: .editorIndentWrappedLines)
        try container.encode(editorEnableAutocomplete, forKey: .editorEnableAutocomplete)
        try container.encode(editorQualifyTableCompletions, forKey: .editorQualifyTableCompletions)
        try container.encode(editorShowSystemSchemas, forKey: .editorShowSystemSchemas)
        try container.encode(editorEnableLiveValidation, forKey: .editorEnableLiveValidation)
        try container.encode(accentColorSource, forKey: .accentColorSource)
        try container.encodeIfPresent(customAccentColorHex, forKey: .customAccentColorHex)
        try container.encode(workspaceTabBarStyle, forKey: .workspaceTabBarStyle)
        try container.encode(tabOverviewStyle, forKey: .tabOverviewStyle)
        try container.encode(resultsAlternateRowShading, forKey: .resultsAlternateRowShading)
        try container.encode(resultsShowRowNumbers, forKey: .resultsShowRowNumbers)
        try container.encode(resultGridColorOverrides, forKey: .resultGridColorOverrides)
        try container.encode(showForeignKeysInInspector, forKey: .showForeignKeysInInspector)
        try container.encode(showJsonInInspector, forKey: .showJsonInInspector)
        try container.encode(resultsInitialRowLimit, forKey: .resultsInitialRowLimit)
        try container.encode(resultSpoolMaxBytes, forKey: .resultSpoolMaxBytes)
        try container.encode(resultSpoolRetentionHours, forKey: .resultSpoolRetentionHours)
        try container.encodeIfPresent(resultSpoolCustomLocation, forKey: .resultSpoolCustomLocation)
        try container.encode(autoOpenInspectorOnSelection, forKey: .autoOpenInspectorOnSelection)
        try container.encode(autoOpenBottomPanel, forKey: .autoOpenBottomPanel)
        try container.encode(diagramPrefetchMode, forKey: .diagramPrefetchMode)
        try container.encode(diagramRefreshCadence, forKey: .diagramRefreshCadence)
        try container.encode(diagramCacheMaxBytes, forKey: .diagramCacheMaxBytes)
        try container.encode(diagramVerifyBeforeRefresh, forKey: .diagramVerifyBeforeRefresh)
        try container.encode(diagramRenderRelationshipsForLargeDiagrams, forKey: .diagramRenderRelationshipsForLargeDiagrams)
        try container.encode(diagramUseThemedAppearance, forKey: .diagramUseThemedAppearance)
        try container.encodeIfPresent(customKeyboardShortcuts, forKey: .customKeyboardShortcuts)
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteIDLight)
        try container.encode(defaultEditorPaletteIDDark, forKey: .defaultEditorPaletteIDDark)
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteID)
        try container.encode(sidebarAutoExpandSections, forKey: .sidebarAutoExpandSections)
        try container.encode(sidebarCustomizePerDatabaseType, forKey: .sidebarCustomizePerDatabaseType)
        try container.encodeIfPresent(sidebarAutoExpandPostgresql, forKey: .sidebarAutoExpandPostgresql)
        try container.encodeIfPresent(sidebarAutoExpandSQLServer, forKey: .sidebarAutoExpandSQLServer)
        try container.encodeIfPresent(sidebarAutoExpandMySQL, forKey: .sidebarAutoExpandMySQL)
        try container.encode(managedPostgresConsoleEnabled, forKey: .managedPostgresConsoleEnabled)
        try container.encode(nativePsqlEnabled, forKey: .nativePsqlEnabled)
        try container.encode(nativePsqlRuntimePreference, forKey: .nativePsqlRuntimePreference)
        try container.encode(nativePsqlAllowSystemBinaryFallback, forKey: .nativePsqlAllowSystemBinaryFallback)
        try container.encode(nativePsqlAllowShellEscape, forKey: .nativePsqlAllowShellEscape)
        try container.encode(nativePsqlAllowFileCommands, forKey: .nativePsqlAllowFileCommands)
        try container.encodeIfPresent(pgToolCustomPath, forKey: .pgToolCustomPath)
        try container.encodeIfPresent(mysqlToolCustomPath, forKey: .mysqlToolCustomPath)
        try container.encode(sidebarIconColorMode, forKey: .sidebarIconColorMode)
        try container.encode(sidebarDensity, forKey: .sidebarDensity)
        try container.encode(activityMonitorRefreshInterval, forKey: .activityMonitorRefreshInterval)
        try container.encode(hideInaccessibleDatabases, forKey: .hideInaccessibleDatabases)
        try container.encode(searchIncludeOfflineDatabases, forKey: .searchIncludeOfflineDatabases)
        try container.encode(searchMinimumQueryLength, forKey: .searchMinimumQueryLength)
        try container.encodeIfPresent(searchDefaultCategories, forKey: .searchDefaultCategories)
        try container.encode(notificationPreferences, forKey: .notificationPreferences)
    }

    func ligaturesEnabled(for fontName: String) -> Bool {
        fontLigatureOverrides[fontName] ?? true
    }

    func defaultPalette(for tone: SQLEditorPalette.Tone) -> SQLEditorTokenPalette? {
        let paletteID = tone == .light ? defaultEditorPaletteIDLight : defaultEditorPaletteIDDark
        if let custom = customEditorPalettes.first(where: { $0.id == paletteID }) {
            return custom
        }
        if let builtIn = SQLEditorPalette.palette(withID: paletteID) {
            return SQLEditorTokenPalette(from: builtIn)
        }
        return nil
    }
}
