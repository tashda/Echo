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

struct GlobalSettings: Codable, Hashable {
    var appearanceMode: AppearanceMode
    var defaultEditorFontSize: Double
    var defaultEditorFontFamily: String
    var defaultEditorTheme: String
    var fontLigatureOverrides: [String: Bool]
    var lastCustomEditorFontFamily: String?
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
    var editorSuggestKeywords: Bool = true
    var editorEnableInlineSuggestions: Bool = true
    var editorSuggestFunctions: Bool = true
    var editorSuggestSnippets: Bool = true
    var editorSuggestHistory: Bool = true
    var editorSuggestJoins: Bool = true
    var editorCompletionAggressiveness: SQLCompletionAggressiveness = .balanced
    var editorShowSystemSchemas: Bool = false
    var editorAllowCommandPeriodTrigger: Bool = true
    var editorAllowControlSpaceTrigger: Bool = true
    var accentColorSource: AccentColorSource
    var customAccentColorHex: String?
    var workspaceTabBarStyle: WorkspaceTabBarStyle = .floating
    var tabOverviewStyle: TabOverviewStyle = .comfortable
    var resultsAlternateRowShading: Bool = false
    var resultsEnableTypeFormatting: Bool = true
    var resultsFormattingMode: ResultsFormattingMode = .immediate
    var foreignKeyDisplayMode: ForeignKeyDisplayMode = .showInspector
    var foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior = .respectInspectorVisibility
    var foreignKeyIncludeRelated: Bool = false
    var resultsInitialRowLimit: Int = 500
    var resultsPreviewBatchSize: Int = 500
    var resultsBackgroundStreamingThreshold: Int = 512
    var resultsStreamingFetchSize: Int = 4_096
    var resultsStreamingMode: ResultStreamingExecutionMode = .auto
    var resultsStreamingFetchRampMultiplier: Int = 24
    var resultsStreamingFetchRampMax: Int = 524_288
    var resultsUseCursorStreaming: Bool = true
    var resultsCursorStreamingLimitThreshold: Int = 25_000
    var mssqlStreamingMode: ResultStreamingExecutionMode = .auto
    var mysqlStreamingMode: ResultStreamingExecutionMode = .auto
    var sqliteStreamingMode: ResultStreamingExecutionMode = .auto
    var resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024
    var resultSpoolRetentionHours: Int = 72
    var resultSpoolCustomLocation: String?
    var autoOpenInspectorOnSelection: Bool = true
    var inspectorWidth: Double?
    var keepTabsInMemory: Bool = false
    var diagramPrefetchMode: DiagramPrefetchMode = .off
    var diagramRefreshCadence: DiagramRefreshCadence = .never
    var diagramCacheMaxBytes: Int = 512 * 1_024 * 1_024
    var diagramVerifyBeforeRefresh: Bool = true
    var diagramRenderRelationshipsForLargeDiagrams: Bool = true
    var diagramUseThemedAppearance: Bool = true
    var usePerTypeStorageLimits: Bool = false
    var echoSenseStorageMaxBytes: Int = 512 * 1_024 * 1_024
    var customKeyboardShortcuts: [String: CustomShortcutBinding]?
    var defaultWindowWidth: Double?
    var defaultWindowHeight: Double?
    var sidebarAutoExpandSections: Set<SidebarAutoExpandSection> = [.databases]
    var sidebarCustomizePerDatabaseType: Bool = false
    var sidebarAutoExpandPostgresql: Set<SidebarAutoExpandSection>?
    var sidebarAutoExpandSQLServer: Set<SidebarAutoExpandSection>?
    var sidebarAutoExpandMySQL: Set<SidebarAutoExpandSection>?

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
        lastCustomEditorFontFamily: String? = nil,
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
        self.lastCustomEditorFontFamily = lastCustomEditorFontFamily
        self.defaultEditorPaletteIDLight = defaultEditorPaletteIDLight
        self.defaultEditorPaletteIDDark = defaultEditorPaletteIDDark
        self.customEditorPalettes = customEditorPalettes
        self.defaultEditorLineHeight = defaultEditorLineHeight
        self.accentColorSource = accentColorSource
    }

    enum CodingKeys: String, CodingKey {
        case appearanceMode, defaultEditorFontSize, defaultEditorFontFamily, defaultEditorTheme
        case fontLigatureOverrides, defaultEditorPaletteID, defaultEditorPaletteIDLight, defaultEditorPaletteIDDark
        case lastCustomEditorFontFamily, customEditorPalettes, defaultEditorLineHeight
        case editorShowLineNumbers, editorHighlightSelectedSymbol, editorHighlightDelay
        case editorWrapLines, editorIndentWrappedLines, editorEnableAutocomplete
        case editorQualifyTableCompletions, editorSuggestKeywords, editorEnableInlineSuggestions
        case editorSuggestFunctions, editorSuggestSnippets, editorSuggestHistory, editorSuggestJoins
        case editorCompletionAggressiveness, editorShowSystemSchemas
        case editorAllowCommandPeriodTrigger, editorAllowControlSpaceTrigger
        case useServerColorAsAccent, accentColorSource, customAccentColorHex, defaultWindowWidth, defaultWindowHeight
        case workspaceTabBarStyle, tabOverviewStyle
        case resultsAlternateRowShading, resultsEnableTypeFormatting, resultsFormattingMode
        case foreignKeyDisplayMode, foreignKeyInspectorBehavior, foreignKeyIncludeRelated
        case resultsInitialRowLimit, resultsPreviewBatchSize
        case resultsBackgroundStreamingThreshold, resultsStreamingFetchSize, resultsStreamingMode
        case resultsStreamingFetchRampMultiplier, resultsStreamingFetchRampMax
        case resultsUseCursorStreaming, resultsCursorStreamingLimitThreshold
        case mssqlStreamingMode, mysqlStreamingMode, sqliteStreamingMode
        case resultSpoolMaxBytes, resultSpoolRetentionHours, resultSpoolCustomLocation
        case autoOpenInspectorOnSelection, inspectorWidth, keepTabsInMemory
        case diagramPrefetchMode, diagramRefreshCadence, diagramCacheMaxBytes
        case diagramVerifyBeforeRefresh, diagramRenderRelationshipsForLargeDiagrams, diagramUseThemedAppearance
        case usePerTypeStorageLimits, echoSenseStorageMaxBytes, customKeyboardShortcuts
        case sidebarAutoExpandSections, sidebarCustomizePerDatabaseType
        case sidebarAutoExpandPostgresql, sidebarAutoExpandSQLServer, sidebarAutoExpandMySQL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? 12.0
        defaultEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .defaultEditorFontFamily) ?? "JetBrainsMono-Regular"
        defaultEditorTheme = try container.decodeIfPresent(String.self, forKey: .defaultEditorTheme) ?? SQLEditorPalette.aurora.id
        fontLigatureOverrides = try container.decodeIfPresent([String: Bool].self, forKey: .fontLigatureOverrides) ?? [:]
        lastCustomEditorFontFamily = try container.decodeIfPresent(String.self, forKey: .lastCustomEditorFontFamily)
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
        editorSuggestKeywords = try container.decodeIfPresent(Bool.self, forKey: .editorSuggestKeywords) ?? true
        editorEnableInlineSuggestions = try container.decodeIfPresent(Bool.self, forKey: .editorEnableInlineSuggestions) ?? true
        editorSuggestFunctions = try container.decodeIfPresent(Bool.self, forKey: .editorSuggestFunctions) ?? true
        editorSuggestSnippets = try container.decodeIfPresent(Bool.self, forKey: .editorSuggestSnippets) ?? true
        editorSuggestHistory = try container.decodeIfPresent(Bool.self, forKey: .editorSuggestHistory) ?? true
        editorSuggestJoins = try container.decodeIfPresent(Bool.self, forKey: .editorSuggestJoins) ?? true
        editorCompletionAggressiveness = try container.decodeIfPresent(SQLCompletionAggressiveness.self, forKey: .editorCompletionAggressiveness) ?? .balanced
        editorShowSystemSchemas = try container.decodeIfPresent(Bool.self, forKey: .editorShowSystemSchemas) ?? false
        editorAllowCommandPeriodTrigger = try container.decodeIfPresent(Bool.self, forKey: .editorAllowCommandPeriodTrigger) ?? true
        editorAllowControlSpaceTrigger = try container.decodeIfPresent(Bool.self, forKey: .editorAllowControlSpaceTrigger) ?? true
        if let source = try container.decodeIfPresent(AccentColorSource.self, forKey: .accentColorSource) {
            accentColorSource = source
        } else {
            let legacyBool = try container.decodeIfPresent(Bool.self, forKey: .useServerColorAsAccent) ?? true
            accentColorSource = legacyBool ? .connection : .system
        }
        customAccentColorHex = try container.decodeIfPresent(String.self, forKey: .customAccentColorHex)
        defaultWindowWidth = try container.decodeIfPresent(Double.self, forKey: .defaultWindowWidth)
        defaultWindowHeight = try container.decodeIfPresent(Double.self, forKey: .defaultWindowHeight)
        workspaceTabBarStyle = try container.decodeIfPresent(WorkspaceTabBarStyle.self, forKey: .workspaceTabBarStyle) ?? .floating
        tabOverviewStyle = try container.decodeIfPresent(TabOverviewStyle.self, forKey: .tabOverviewStyle) ?? .comfortable
        resultsAlternateRowShading = try container.decodeIfPresent(Bool.self, forKey: .resultsAlternateRowShading) ?? false
        resultsEnableTypeFormatting = try container.decodeIfPresent(Bool.self, forKey: .resultsEnableTypeFormatting) ?? true
        resultsFormattingMode = (try? container.decodeIfPresent(ResultsFormattingMode.self, forKey: .resultsFormattingMode)) ?? .immediate
        foreignKeyDisplayMode = try container.decodeIfPresent(ForeignKeyDisplayMode.self, forKey: .foreignKeyDisplayMode) ?? .showInspector
        foreignKeyInspectorBehavior = try container.decodeIfPresent(ForeignKeyInspectorBehavior.self, forKey: .foreignKeyInspectorBehavior) ?? .respectInspectorVisibility
        foreignKeyIncludeRelated = try container.decodeIfPresent(Bool.self, forKey: .foreignKeyIncludeRelated) ?? false
        resultsInitialRowLimit = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsInitialRowLimit) ?? 500)
        resultsPreviewBatchSize = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsPreviewBatchSize) ?? 500)
        resultsBackgroundStreamingThreshold = max(100, try container.decodeIfPresent(Int.self, forKey: .resultsBackgroundStreamingThreshold) ?? 512)
        resultsStreamingFetchSize = max(128, try container.decodeIfPresent(Int.self, forKey: .resultsStreamingFetchSize) ?? 4_096)
        resultsStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .resultsStreamingMode)) ?? .auto
        resultsStreamingFetchRampMultiplier = max(1, min((try? container.decodeIfPresent(Int.self, forKey: .resultsStreamingFetchRampMultiplier)) ?? 24, 64))
        resultsStreamingFetchRampMax = max(256, min((try? container.decodeIfPresent(Int.self, forKey: .resultsStreamingFetchRampMax)) ?? 524_288, 1_048_576))
        resultsUseCursorStreaming = try container.decodeIfPresent(Bool.self, forKey: .resultsUseCursorStreaming) ?? true
        resultsCursorStreamingLimitThreshold = max(0, try container.decodeIfPresent(Int.self, forKey: .resultsCursorStreamingLimitThreshold) ?? 1000)
        resultSpoolMaxBytes = try container.decodeIfPresent(Int.self, forKey: .resultSpoolMaxBytes) ?? 5 * 1_024 * 1_024 * 1_024
        resultSpoolRetentionHours = try container.decodeIfPresent(Int.self, forKey: .resultSpoolRetentionHours) ?? 72
        resultSpoolCustomLocation = try container.decodeIfPresent(String.self, forKey: .resultSpoolCustomLocation)
        autoOpenInspectorOnSelection = try container.decodeIfPresent(Bool.self, forKey: .autoOpenInspectorOnSelection) ?? true
        inspectorWidth = try container.decodeIfPresent(Double.self, forKey: .inspectorWidth)
        keepTabsInMemory = try container.decodeIfPresent(Bool.self, forKey: .keepTabsInMemory) ?? false
        diagramPrefetchMode = try container.decodeIfPresent(DiagramPrefetchMode.self, forKey: .diagramPrefetchMode) ?? .off
        diagramRefreshCadence = try container.decodeIfPresent(DiagramRefreshCadence.self, forKey: .diagramRefreshCadence) ?? .never
        diagramCacheMaxBytes = max(64 * 1_024 * 1_024, try container.decodeIfPresent(Int.self, forKey: .diagramCacheMaxBytes) ?? 512 * 1_024 * 1_024)
        diagramVerifyBeforeRefresh = try container.decodeIfPresent(Bool.self, forKey: .diagramVerifyBeforeRefresh) ?? true
        diagramRenderRelationshipsForLargeDiagrams = try container.decodeIfPresent(Bool.self, forKey: .diagramRenderRelationshipsForLargeDiagrams) ?? true
        diagramUseThemedAppearance = try container.decodeIfPresent(Bool.self, forKey: .diagramUseThemedAppearance) ?? true
        usePerTypeStorageLimits = try container.decodeIfPresent(Bool.self, forKey: .usePerTypeStorageLimits) ?? false
        echoSenseStorageMaxBytes = try container.decodeIfPresent(Int.self, forKey: .echoSenseStorageMaxBytes) ?? 512 * 1_024 * 1_024
        customKeyboardShortcuts = try container.decodeIfPresent([String: CustomShortcutBinding].self, forKey: .customKeyboardShortcuts)
        mssqlStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .mssqlStreamingMode)) ?? .auto
        mysqlStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .mysqlStreamingMode)) ?? .auto
        sqliteStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .sqliteStreamingMode)) ?? .auto
        sidebarAutoExpandSections = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandSections) ?? [.databases]
        sidebarCustomizePerDatabaseType = try container.decodeIfPresent(Bool.self, forKey: .sidebarCustomizePerDatabaseType) ?? false
        sidebarAutoExpandPostgresql = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandPostgresql)
        sidebarAutoExpandSQLServer = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandSQLServer)
        sidebarAutoExpandMySQL = try container.decodeIfPresent(Set<SidebarAutoExpandSection>.self, forKey: .sidebarAutoExpandMySQL)
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
        try container.encode(defaultEditorLineHeight, forKey: .defaultEditorLineHeight)
        try container.encode(editorShowLineNumbers, forKey: .editorShowLineNumbers)
        try container.encode(editorHighlightSelectedSymbol, forKey: .editorHighlightSelectedSymbol)
        try container.encode(editorHighlightDelay, forKey: .editorHighlightDelay)
        try container.encode(editorWrapLines, forKey: .editorWrapLines)
        try container.encode(editorIndentWrappedLines, forKey: .editorIndentWrappedLines)
        try container.encode(editorEnableAutocomplete, forKey: .editorEnableAutocomplete)
        try container.encode(editorQualifyTableCompletions, forKey: .editorQualifyTableCompletions)
        try container.encode(editorSuggestKeywords, forKey: .editorSuggestKeywords)
        try container.encode(editorEnableInlineSuggestions, forKey: .editorEnableInlineSuggestions)
        try container.encode(editorSuggestFunctions, forKey: .editorSuggestFunctions)
        try container.encode(editorSuggestSnippets, forKey: .editorSuggestSnippets)
        try container.encode(editorSuggestHistory, forKey: .editorSuggestHistory)
        try container.encode(editorSuggestJoins, forKey: .editorSuggestJoins)
        try container.encode(editorCompletionAggressiveness, forKey: .editorCompletionAggressiveness)
        try container.encode(editorShowSystemSchemas, forKey: .editorShowSystemSchemas)
        try container.encode(editorAllowCommandPeriodTrigger, forKey: .editorAllowCommandPeriodTrigger)
        try container.encode(editorAllowControlSpaceTrigger, forKey: .editorAllowControlSpaceTrigger)
        try container.encode(accentColorSource, forKey: .accentColorSource)
        try container.encodeIfPresent(customAccentColorHex, forKey: .customAccentColorHex)
        try container.encode(defaultWindowWidth, forKey: .defaultWindowWidth)
        try container.encode(defaultWindowHeight, forKey: .defaultWindowHeight)
        try container.encode(workspaceTabBarStyle, forKey: .workspaceTabBarStyle)
        try container.encode(tabOverviewStyle, forKey: .tabOverviewStyle)
        try container.encode(resultsAlternateRowShading, forKey: .resultsAlternateRowShading)
        try container.encode(resultsEnableTypeFormatting, forKey: .resultsEnableTypeFormatting)
        try container.encode(resultsFormattingMode, forKey: .resultsFormattingMode)
        try container.encode(foreignKeyDisplayMode, forKey: .foreignKeyDisplayMode)
        try container.encode(foreignKeyInspectorBehavior, forKey: .foreignKeyInspectorBehavior)
        try container.encode(foreignKeyIncludeRelated, forKey: .foreignKeyIncludeRelated)
        try container.encode(resultsInitialRowLimit, forKey: .resultsInitialRowLimit)
        try container.encode(resultsPreviewBatchSize, forKey: .resultsPreviewBatchSize)
        try container.encode(resultsBackgroundStreamingThreshold, forKey: .resultsBackgroundStreamingThreshold)
        try container.encode(resultsStreamingFetchSize, forKey: .resultsStreamingFetchSize)
        try container.encode(resultsStreamingMode, forKey: .resultsStreamingMode)
        try container.encode(resultsStreamingFetchRampMultiplier, forKey: .resultsStreamingFetchRampMultiplier)
        try container.encode(resultsStreamingFetchRampMax, forKey: .resultsStreamingFetchRampMax)
        try container.encode(resultsUseCursorStreaming, forKey: .resultsUseCursorStreaming)
        try container.encode(resultSpoolMaxBytes, forKey: .resultSpoolMaxBytes)
        try container.encode(resultSpoolRetentionHours, forKey: .resultSpoolRetentionHours)
        try container.encodeIfPresent(resultSpoolCustomLocation, forKey: .resultSpoolCustomLocation)
        try container.encode(autoOpenInspectorOnSelection, forKey: .autoOpenInspectorOnSelection)
        try container.encodeIfPresent(inspectorWidth, forKey: .inspectorWidth)
        try container.encode(keepTabsInMemory, forKey: .keepTabsInMemory)
        try container.encode(diagramPrefetchMode, forKey: .diagramPrefetchMode)
        try container.encode(diagramRefreshCadence, forKey: .diagramRefreshCadence)
        try container.encode(diagramCacheMaxBytes, forKey: .diagramCacheMaxBytes)
        try container.encode(diagramVerifyBeforeRefresh, forKey: .diagramVerifyBeforeRefresh)
        try container.encode(diagramRenderRelationshipsForLargeDiagrams, forKey: .diagramRenderRelationshipsForLargeDiagrams)
        try container.encode(diagramUseThemedAppearance, forKey: .diagramUseThemedAppearance)
        try container.encode(usePerTypeStorageLimits, forKey: .usePerTypeStorageLimits)
        try container.encode(echoSenseStorageMaxBytes, forKey: .echoSenseStorageMaxBytes)
        try container.encodeIfPresent(customKeyboardShortcuts, forKey: .customKeyboardShortcuts)
        try container.encode(mssqlStreamingMode, forKey: .mssqlStreamingMode)
        try container.encode(mysqlStreamingMode, forKey: .mysqlStreamingMode)
        try container.encode(sqliteStreamingMode, forKey: .sqliteStreamingMode)
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteIDLight)
        try container.encode(defaultEditorPaletteIDDark, forKey: .defaultEditorPaletteIDDark)
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteID)
        try container.encode(sidebarAutoExpandSections, forKey: .sidebarAutoExpandSections)
        try container.encode(sidebarCustomizePerDatabaseType, forKey: .sidebarCustomizePerDatabaseType)
        try container.encodeIfPresent(sidebarAutoExpandPostgresql, forKey: .sidebarAutoExpandPostgresql)
        try container.encodeIfPresent(sidebarAutoExpandSQLServer, forKey: .sidebarAutoExpandSQLServer)
        try container.encodeIfPresent(sidebarAutoExpandMySQL, forKey: .sidebarAutoExpandMySQL)
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
