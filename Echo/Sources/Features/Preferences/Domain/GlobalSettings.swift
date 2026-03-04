import Foundation
import SwiftUI
import EchoSense

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
    var useServerColorAsAccent: Bool
    var activeThemeIDLight: AppColorTheme.ID?
    var activeThemeIDDark: AppColorTheme.ID?
    var themeTabs: Bool = false
    var workspaceTabBarStyle: WorkspaceTabBarStyle = .floating
    var tabOverviewStyle: TabOverviewStyle = .comfortable
    var themeResultsGrid: Bool = true
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
    // Engine-specific UI preferences (used by settings; runtime may map per engine)
    var mssqlStreamingMode: ResultStreamingExecutionMode = .auto
    var mysqlStreamingMode: ResultStreamingExecutionMode = .auto
    var sqliteStreamingMode: ResultStreamingExecutionMode = .auto
    var resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024
    var resultSpoolRetentionHours: Int = 72
    var resultSpoolCustomLocation: String?
    var inspectorWidth: Double?
    var keepTabsInMemory: Bool = false
    var diagramPrefetchMode: DiagramPrefetchMode = .off
    var diagramRefreshCadence: DiagramRefreshCadence = .never
    var diagramCacheMaxBytes: Int = 512 * 1_024 * 1_024
    var diagramVerifyBeforeRefresh: Bool = true
    var diagramRenderRelationshipsForLargeDiagrams: Bool = true
    var diagramUseThemedAppearance: Bool = true

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
        editorQualifyTableCompletions: Bool = false,
        editorSuggestKeywords: Bool = true,
        editorEnableInlineSuggestions: Bool = true,
        editorSuggestFunctions: Bool = true,
        editorSuggestSnippets: Bool = true,
        editorSuggestHistory: Bool = true,
        editorSuggestJoins: Bool = true,
        editorCompletionAggressiveness: SQLCompletionAggressiveness = .balanced,
        editorShowSystemSchemas: Bool = false,
        editorAllowCommandPeriodTrigger: Bool = true,
        editorAllowControlSpaceTrigger: Bool = true,
        useServerColorAsAccent: Bool = true,
        themeTabs: Bool = false,
        workspaceTabBarStyle: WorkspaceTabBarStyle = .floating,
        tabOverviewStyle: TabOverviewStyle = .comfortable,
        themeResultsGrid: Bool = true,
        resultsAlternateRowShading: Bool = false,
        resultsEnableTypeFormatting: Bool = true,
        resultsFormattingMode: ResultsFormattingMode = .immediate,
        foreignKeyDisplayMode: ForeignKeyDisplayMode = .showInspector,
        foreignKeyInspectorBehavior: ForeignKeyInspectorBehavior = .respectInspectorVisibility,
        foreignKeyIncludeRelated: Bool = false,
        resultsInitialRowLimit: Int = 500,
        resultsPreviewBatchSize: Int = 500,
        resultsBackgroundStreamingThreshold: Int = 512,
        resultsStreamingFetchSize: Int = 4_096,
        resultsStreamingMode: ResultStreamingExecutionMode = .auto,
        resultsStreamingFetchRampMultiplier: Int = 24,
        resultsStreamingFetchRampMax: Int = 524_288,
        resultsUseCursorStreaming: Bool = true,
        resultsCursorStreamingLimitThreshold: Int = 25_000,
        mssqlStreamingMode: ResultStreamingExecutionMode = .auto,
        mysqlStreamingMode: ResultStreamingExecutionMode = .auto,
        sqliteStreamingMode: ResultStreamingExecutionMode = .auto,
        resultSpoolMaxBytes: Int = 5 * 1_024 * 1_024 * 1_024,
        resultSpoolRetentionHours: Int = 72,
        resultSpoolCustomLocation: String? = nil,
        inspectorWidth: Double? = nil,
        defaultWindowWidth: Double? = nil,
        defaultWindowHeight: Double? = nil,
        activeThemeIDLight: AppColorTheme.ID? = nil,
        activeThemeIDDark: AppColorTheme.ID? = nil,
        keepTabsInMemory: Bool = false,
        diagramPrefetchMode: DiagramPrefetchMode = .off,
        diagramRefreshCadence: DiagramRefreshCadence = .never,
        diagramCacheMaxBytes: Int = 512 * 1_024 * 1_024,
        diagramVerifyBeforeRefresh: Bool = true,
        diagramRenderRelationshipsForLargeDiagrams: Bool = true,
        diagramUseThemedAppearance: Bool = true
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
        self.editorQualifyTableCompletions = editorQualifyTableCompletions
        self.editorSuggestKeywords = editorSuggestKeywords
        self.editorEnableInlineSuggestions = editorEnableInlineSuggestions
        self.editorSuggestFunctions = editorSuggestFunctions
        self.editorSuggestSnippets = editorSuggestSnippets
        self.editorSuggestHistory = editorSuggestHistory
        self.editorSuggestJoins = editorSuggestJoins
        self.editorCompletionAggressiveness = editorCompletionAggressiveness
        self.editorShowSystemSchemas = editorShowSystemSchemas
        self.editorAllowCommandPeriodTrigger = editorAllowCommandPeriodTrigger
        self.editorAllowControlSpaceTrigger = editorAllowControlSpaceTrigger
        self.useServerColorAsAccent = useServerColorAsAccent
        self.themeTabs = themeTabs
        self.workspaceTabBarStyle = workspaceTabBarStyle
        self.tabOverviewStyle = tabOverviewStyle
        self.themeResultsGrid = themeResultsGrid
        self.resultsAlternateRowShading = resultsAlternateRowShading
        self.resultsEnableTypeFormatting = resultsEnableTypeFormatting
        self.resultsFormattingMode = resultsFormattingMode
        self.foreignKeyDisplayMode = foreignKeyDisplayMode
        self.foreignKeyInspectorBehavior = foreignKeyInspectorBehavior
        self.foreignKeyIncludeRelated = foreignKeyIncludeRelated
        self.resultsInitialRowLimit = max(100, resultsInitialRowLimit)
        self.resultsPreviewBatchSize = max(100, resultsPreviewBatchSize)
        self.resultsBackgroundStreamingThreshold = max(100, resultsBackgroundStreamingThreshold)
        self.resultsStreamingFetchSize = max(128, resultsStreamingFetchSize)
        self.resultsStreamingMode = resultsStreamingMode
        self.resultsStreamingFetchRampMultiplier = max(1, min(resultsStreamingFetchRampMultiplier, 64))
        self.resultsStreamingFetchRampMax = max(256, min(resultsStreamingFetchRampMax, 1_048_576))
        self.resultsUseCursorStreaming = resultsUseCursorStreaming
        self.resultsCursorStreamingLimitThreshold = max(0, resultsCursorStreamingLimitThreshold)
        self.mssqlStreamingMode = mssqlStreamingMode
        self.mysqlStreamingMode = mysqlStreamingMode
        self.sqliteStreamingMode = sqliteStreamingMode
        self.resultSpoolMaxBytes = resultSpoolMaxBytes
        self.resultSpoolRetentionHours = resultSpoolRetentionHours
        self.resultSpoolCustomLocation = resultSpoolCustomLocation
        self.inspectorWidth = inspectorWidth
        self.defaultWindowWidth = defaultWindowWidth
        self.defaultWindowHeight = defaultWindowHeight
        self.activeThemeIDLight = activeThemeIDLight
        self.activeThemeIDDark = activeThemeIDDark
        self.keepTabsInMemory = keepTabsInMemory
        self.diagramPrefetchMode = diagramPrefetchMode
        self.diagramRefreshCadence = diagramRefreshCadence
        self.diagramCacheMaxBytes = max(64 * 1_024 * 1_024, diagramCacheMaxBytes)
        self.diagramVerifyBeforeRefresh = diagramVerifyBeforeRefresh
        self.diagramRenderRelationshipsForLargeDiagrams = diagramRenderRelationshipsForLargeDiagrams
        self.diagramUseThemedAppearance = diagramUseThemedAppearance
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
        case editorQualifyTableCompletions
        case editorSuggestKeywords
        case editorEnableInlineSuggestions
        case editorSuggestFunctions
        case editorSuggestSnippets
        case editorSuggestHistory
        case editorSuggestJoins
        case editorCompletionAggressiveness
        case editorShowSystemSchemas
        case editorAllowCommandPeriodTrigger
        case editorAllowControlSpaceTrigger
        case useServerColorAsAccent
        case defaultWindowWidth
        case defaultWindowHeight
        case activeThemeIDLight
        case activeThemeIDDark
        case themeTabs
        case workspaceTabBarStyle
        case themeResultsGrid
        case resultsAlternateRowShading
        case resultsEnableTypeFormatting
        case resultsFormattingMode
        case foreignKeyDisplayMode
        case foreignKeyInspectorBehavior
        case foreignKeyIncludeRelated
        case resultsInitialRowLimit
        case resultsPreviewBatchSize
        case resultsBackgroundStreamingThreshold
        case resultsStreamingFetchSize
        case resultsStreamingMode
        case resultsStreamingFetchRampMultiplier
        case resultsStreamingFetchRampMax
        case resultsUseCursorStreaming
        case resultsCursorStreamingLimitThreshold
        case mssqlStreamingMode
        case mysqlStreamingMode
        case sqliteStreamingMode
        case resultSpoolMaxBytes
        case resultSpoolRetentionHours
        case resultSpoolCustomLocation
        case inspectorWidth
        case keepTabsInMemory
        case diagramPrefetchMode
        case diagramRefreshCadence
        case diagramCacheMaxBytes
        case diagramVerifyBeforeRefresh
        case diagramRenderRelationshipsForLargeDiagrams
        case diagramUseThemedAppearance
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
        useServerColorAsAccent = try container.decodeIfPresent(Bool.self, forKey: .useServerColorAsAccent) ?? true
        defaultWindowWidth = try container.decodeIfPresent(Double.self, forKey: .defaultWindowWidth)
        defaultWindowHeight = try container.decodeIfPresent(Double.self, forKey: .defaultWindowHeight)
        activeThemeIDLight = try container.decodeIfPresent(AppColorTheme.ID.self, forKey: .activeThemeIDLight)
        activeThemeIDDark = try container.decodeIfPresent(AppColorTheme.ID.self, forKey: .activeThemeIDDark)
        themeTabs = try container.decodeIfPresent(Bool.self, forKey: .themeTabs) ?? false
        workspaceTabBarStyle = try container.decodeIfPresent(WorkspaceTabBarStyle.self, forKey: .workspaceTabBarStyle) ?? .floating
        themeResultsGrid = try container.decodeIfPresent(Bool.self, forKey: .themeResultsGrid) ?? true
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
        resultsStreamingFetchRampMultiplier = {
            let raw = (try? container.decodeIfPresent(Int.self, forKey: .resultsStreamingFetchRampMultiplier)) ?? 24
            return max(1, min(raw, 64))
        }()
        resultsStreamingFetchRampMax = {
            let raw = (try? container.decodeIfPresent(Int.self, forKey: .resultsStreamingFetchRampMax)) ?? 524_288
            return max(256, min(raw, 1_048_576))
        }()
        resultsUseCursorStreaming = try container.decodeIfPresent(Bool.self, forKey: .resultsUseCursorStreaming) ?? true
        resultsCursorStreamingLimitThreshold = max(0, try container.decodeIfPresent(Int.self, forKey: .resultsCursorStreamingLimitThreshold) ?? 1000)
        resultSpoolMaxBytes = try container.decodeIfPresent(Int.self, forKey: .resultSpoolMaxBytes) ?? 5 * 1_024 * 1_024 * 1_024
        resultSpoolRetentionHours = try container.decodeIfPresent(Int.self, forKey: .resultSpoolRetentionHours) ?? 72
        resultSpoolCustomLocation = try container.decodeIfPresent(String.self, forKey: .resultSpoolCustomLocation)
        inspectorWidth = try container.decodeIfPresent(Double.self, forKey: .inspectorWidth)
        keepTabsInMemory = try container.decodeIfPresent(Bool.self, forKey: .keepTabsInMemory) ?? false
        diagramPrefetchMode = try container.decodeIfPresent(DiagramPrefetchMode.self, forKey: .diagramPrefetchMode) ?? .off
        diagramRefreshCadence = try container.decodeIfPresent(DiagramRefreshCadence.self, forKey: .diagramRefreshCadence) ?? .never
        diagramCacheMaxBytes = max(64 * 1_024 * 1_024, try container.decodeIfPresent(Int.self, forKey: .diagramCacheMaxBytes) ?? 512 * 1_024 * 1_024)
        diagramVerifyBeforeRefresh = try container.decodeIfPresent(Bool.self, forKey: .diagramVerifyBeforeRefresh) ?? true
        diagramRenderRelationshipsForLargeDiagrams = try container.decodeIfPresent(Bool.self, forKey: .diagramRenderRelationshipsForLargeDiagrams) ?? true
        diagramUseThemedAppearance = try container.decodeIfPresent(Bool.self, forKey: .diagramUseThemedAppearance) ?? true
        mssqlStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .mssqlStreamingMode)) ?? .auto
        mysqlStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .mysqlStreamingMode)) ?? .auto
        sqliteStreamingMode = (try? container.decodeIfPresent(ResultStreamingExecutionMode.self, forKey: .sqliteStreamingMode)) ?? .auto
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
        try container.encode(useServerColorAsAccent, forKey: .useServerColorAsAccent)
        try container.encode(defaultWindowWidth, forKey: .defaultWindowWidth)
        try container.encode(defaultWindowHeight, forKey: .defaultWindowHeight)
        try container.encodeIfPresent(activeThemeIDLight, forKey: .activeThemeIDLight)
        try container.encodeIfPresent(activeThemeIDDark, forKey: .activeThemeIDDark)
        try container.encode(themeTabs, forKey: .themeTabs)
        try container.encode(workspaceTabBarStyle, forKey: .workspaceTabBarStyle)
        try container.encode(themeResultsGrid, forKey: .themeResultsGrid)
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
        try container.encodeIfPresent(inspectorWidth, forKey: .inspectorWidth)
        try container.encode(keepTabsInMemory, forKey: .keepTabsInMemory)
        try container.encode(diagramPrefetchMode, forKey: .diagramPrefetchMode)
        try container.encode(diagramRefreshCadence, forKey: .diagramRefreshCadence)
        try container.encode(diagramCacheMaxBytes, forKey: .diagramCacheMaxBytes)
        try container.encode(diagramVerifyBeforeRefresh, forKey: .diagramVerifyBeforeRefresh)
        try container.encode(diagramRenderRelationshipsForLargeDiagrams, forKey: .diagramRenderRelationshipsForLargeDiagrams)
        try container.encode(diagramUseThemedAppearance, forKey: .diagramUseThemedAppearance)
        try container.encode(mssqlStreamingMode, forKey: .mssqlStreamingMode)
        try container.encode(mysqlStreamingMode, forKey: .mysqlStreamingMode)
        try container.encode(sqliteStreamingMode, forKey: .sqliteStreamingMode)

        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteIDLight)
        try container.encode(defaultEditorPaletteIDDark, forKey: .defaultEditorPaletteIDDark)

        // Persist the legacy field so older builds can still read a sensible default.
        try container.encode(defaultEditorPaletteIDLight, forKey: .defaultEditorPaletteID)
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
