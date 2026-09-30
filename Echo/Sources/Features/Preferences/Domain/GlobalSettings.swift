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
    var editorStatementFocus: Bool = true
    var editorOutlineEdge: Bool = false
    var editorGhostTextCompletion: Bool = false
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
    var objectBrowserCacheMaxBytes: Int = 512 * 1_024 * 1_024
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
    /// Round 21, script results (E3): a PostgreSQL script stops at a failed statement unless this is on.
    var postgresScriptsContinueAfterError: Bool = false
    var pgToolCustomPath: String?
    var mysqlToolCustomPath: String?
    var sidebarIconColorMode: SidebarIconColorMode = .colorful
    var sidebarDensity: SidebarDensity = .medium
    var sidebarExpandOneConnectionAtATime: Bool = true
    /// Pins "server › database" above the Explorer once the server's header scrolls away.
    /// The Explorer's scroll bar; hidden by default (round 9, SB3).
    var sidebarShowsScrollBar: Bool = false
    /// Shows object folders with nothing in them (Views, Functions…) in the Explorer.
    var sidebarShowsEmptyFolders: Bool = false
    // Canvas-and-cards redesign (Design/01-principles.md, rule 7).
    var interfaceMotionSpeed: InterfaceMotionSpeed = .standard
    var workspaceGutter: WorkspaceGutter = .standard
    var workspaceCornerRadius: WorkspaceCornerRadius = .standard
    var railItemSize: RailItemSize = .medium
    var collapsedServerClick: CollapsedServerClickBehavior = .peekCommandReopens
    var sidebarMonochromeVariant: SidebarMonochromeVariant = .accentOnOpen
    /// The section dock's icons, apart from the tree's (round 16): mono by default.
    var sidebarDockIconStyle: SidebarDockIconStyle = .mono
    /// Each database type's dock (keyed by `DatabaseType.rawValue`): the sections shown, in
    /// order, as section keys. A type missing here uses its blueprint's default.
    var sidebarDockSections: [String: [String]] = [:]
    var editorGutterStyle: EditorGutterStyle = .subtle
    /// 1 once the editor moved to 13pt with 1.55 line spacing (design board, 2026-09-30).
    var editorTypographyRevision = 1
    var resultsMonospacedCells: Bool = false
    var toolbarProjectButtonStyle: ToolbarProjectButtonStyle = .account
    var activityMonitorRefreshInterval: Double = 5.0
    var hideInaccessibleDatabases: Bool = false
    var sidebarHideOfflineDatabasesByDefault: Bool = false
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
        defaultEditorFontSize: Double = Double(SQLEditorTheme.defaultFontSize),
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
        case editorStatementFocus
        case editorOutlineEdge
        case editorGhostTextCompletion
        case useServerColorAsAccent, accentColorSource, customAccentColorHex
        case workspaceTabBarStyle, tabOverviewStyle
        case resultsAlternateRowShading, resultsShowRowNumbers, resultGridColorOverrides
        case showForeignKeysInInspector, showJsonInInspector
        case resultsInitialRowLimit
        case resultSpoolMaxBytes, resultSpoolRetentionHours, resultSpoolCustomLocation
        case objectBrowserCacheMaxBytes
        case autoOpenInspectorOnSelection, autoOpenBottomPanel
        case diagramPrefetchMode, diagramRefreshCadence, diagramCacheMaxBytes
        case diagramVerifyBeforeRefresh, diagramRenderRelationshipsForLargeDiagrams, diagramUseThemedAppearance
        case customKeyboardShortcuts
        case sidebarAutoExpandSections, sidebarCustomizePerDatabaseType
        case sidebarAutoExpandPostgresql, sidebarAutoExpandSQLServer, sidebarAutoExpandMySQL
        case managedPostgresConsoleEnabled
        case postgresScriptsContinueAfterError
        case pgToolCustomPath
        case mysqlToolCustomPath
        case sidebarIconColorMode
        case sidebarDensity
        case sidebarExpandOneConnectionAtATime
        case sidebarShowsScrollBar
        case sidebarShowsEmptyFolders
        case interfaceMotionSpeed
        case workspaceGutter
        case workspaceCornerRadius
        case railItemSize
        case collapsedServerClick
        case sidebarMonochromeVariant
        case sidebarDockIconStyle
        case sidebarDockSections
        case editorGutterStyle
        case editorTypographyRevision
        case resultsMonospacedCells
        case sidebarColoredIcons
        case activityMonitorRefreshInterval
        case hideInaccessibleDatabases
        case sidebarHideOfflineDatabasesByDefault
        case searchIncludeOfflineDatabases
        case searchMinimumQueryLength
        case searchDefaultCategories
        case notificationPreferences
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appearanceMode = try container.decodeIfPresent(AppearanceMode.self, forKey: .appearanceMode) ?? .system
        defaultEditorFontSize = try container.decodeIfPresent(Double.self, forKey: .defaultEditorFontSize) ?? Double(SQLEditorTheme.defaultFontSize)
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
        editorStatementFocus = try container.decodeIfPresent(Bool.self, forKey: .editorStatementFocus) ?? true
        editorOutlineEdge = try container.decodeIfPresent(Bool.self, forKey: .editorOutlineEdge) ?? false
        editorGhostTextCompletion = try container.decodeIfPresent(Bool.self, forKey: .editorGhostTextCompletion) ?? false
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
        objectBrowserCacheMaxBytes = max(64 * 1_024 * 1_024, try container.decodeIfPresent(Int.self, forKey: .objectBrowserCacheMaxBytes) ?? 512 * 1_024 * 1_024)
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
        postgresScriptsContinueAfterError = try container.decodeIfPresent(Bool.self, forKey: .postgresScriptsContinueAfterError) ?? false
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

        sidebarExpandOneConnectionAtATime = try container.decodeIfPresent(
            Bool.self,
            forKey: .sidebarExpandOneConnectionAtATime
        ) ?? true

        sidebarShowsScrollBar = try container.decodeIfPresent(Bool.self, forKey: .sidebarShowsScrollBar) ?? false

        sidebarShowsEmptyFolders = try container.decodeIfPresent(
            Bool.self,
            forKey: .sidebarShowsEmptyFolders
        ) ?? false

        // Unknown values (from a newer build) fall back to the default instead of failing.
        interfaceMotionSpeed = (try? container.decodeIfPresent(InterfaceMotionSpeed.self, forKey: .interfaceMotionSpeed)) ?? .standard
        workspaceGutter = (try? container.decodeIfPresent(WorkspaceGutter.self, forKey: .workspaceGutter)) ?? .standard
        workspaceCornerRadius = (try? container.decodeIfPresent(WorkspaceCornerRadius.self, forKey: .workspaceCornerRadius)) ?? .standard
        railItemSize = (try? container.decodeIfPresent(RailItemSize.self, forKey: .railItemSize)) ?? .medium
        collapsedServerClick = (try? container.decodeIfPresent(CollapsedServerClickBehavior.self, forKey: .collapsedServerClick)) ?? .peekCommandReopens
        sidebarMonochromeVariant = (try? container.decodeIfPresent(SidebarMonochromeVariant.self, forKey: .sidebarMonochromeVariant)) ?? .accentOnOpen
        sidebarDockIconStyle = (try? container.decodeIfPresent(SidebarDockIconStyle.self, forKey: .sidebarDockIconStyle)) ?? .mono
        sidebarDockSections = (try? container.decodeIfPresent([String: [String]].self, forKey: .sidebarDockSections)) ?? [:]
        editorGutterStyle = (try? container.decodeIfPresent(EditorGutterStyle.self, forKey: .editorGutterStyle)) ?? .subtle
        // Settings still on the old defaults (12pt, single spacing) move to the new ones once.
        if (try container.decodeIfPresent(Int.self, forKey: .editorTypographyRevision) ?? 0) < 1 {
            if defaultEditorFontSize == 12 { defaultEditorFontSize = Double(SQLEditorTheme.defaultFontSize) }
            if defaultEditorLineHeight == 1 { defaultEditorLineHeight = Double(SQLEditorTheme.defaultLineHeight) }
        }
        editorTypographyRevision = 1
        resultsMonospacedCells = try container.decodeIfPresent(Bool.self, forKey: .resultsMonospacedCells) ?? false

        activityMonitorRefreshInterval = try container.decodeIfPresent(Double.self, forKey: .activityMonitorRefreshInterval) ?? 5.0

        hideInaccessibleDatabases = try container.decodeIfPresent(Bool.self, forKey: .hideInaccessibleDatabases) ?? false
        sidebarHideOfflineDatabasesByDefault = try container.decodeIfPresent(Bool.self, forKey: .sidebarHideOfflineDatabasesByDefault) ?? false
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
        try container.encode(editorStatementFocus, forKey: .editorStatementFocus)
        try container.encode(editorOutlineEdge, forKey: .editorOutlineEdge)
        try container.encode(editorGhostTextCompletion, forKey: .editorGhostTextCompletion)
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
        try container.encode(objectBrowserCacheMaxBytes, forKey: .objectBrowserCacheMaxBytes)
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
        try container.encode(postgresScriptsContinueAfterError, forKey: .postgresScriptsContinueAfterError)
        try container.encodeIfPresent(pgToolCustomPath, forKey: .pgToolCustomPath)
        try container.encodeIfPresent(mysqlToolCustomPath, forKey: .mysqlToolCustomPath)
        try container.encode(sidebarIconColorMode, forKey: .sidebarIconColorMode)
        try container.encode(sidebarDensity, forKey: .sidebarDensity)
        try container.encode(sidebarExpandOneConnectionAtATime, forKey: .sidebarExpandOneConnectionAtATime)
        try container.encode(sidebarShowsScrollBar, forKey: .sidebarShowsScrollBar)
        try container.encode(sidebarShowsEmptyFolders, forKey: .sidebarShowsEmptyFolders)
        try container.encode(interfaceMotionSpeed, forKey: .interfaceMotionSpeed)
        try container.encode(workspaceGutter, forKey: .workspaceGutter)
        try container.encode(workspaceCornerRadius, forKey: .workspaceCornerRadius)
        try container.encode(railItemSize, forKey: .railItemSize)
        try container.encode(collapsedServerClick, forKey: .collapsedServerClick)
        try container.encode(sidebarMonochromeVariant, forKey: .sidebarMonochromeVariant)
        try container.encode(sidebarDockIconStyle, forKey: .sidebarDockIconStyle)
        try container.encode(sidebarDockSections, forKey: .sidebarDockSections)
        try container.encode(editorGutterStyle, forKey: .editorGutterStyle)
        try container.encode(editorTypographyRevision, forKey: .editorTypographyRevision)
        try container.encode(resultsMonospacedCells, forKey: .resultsMonospacedCells)
        try container.encode(activityMonitorRefreshInterval, forKey: .activityMonitorRefreshInterval)
        try container.encode(hideInaccessibleDatabases, forKey: .hideInaccessibleDatabases)
        try container.encode(sidebarHideOfflineDatabasesByDefault, forKey: .sidebarHideOfflineDatabasesByDefault)
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
