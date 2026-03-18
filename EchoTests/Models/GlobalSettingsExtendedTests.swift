import Testing
import Foundation
@testable import Echo

@MainActor
@Suite("GlobalSettings Extended")
struct GlobalSettingsExtendedTests {

    // MARK: - AccentColorSource

    @Test func accentColorSourceAllCases() {
        let cases = AccentColorSource.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.system))
        #expect(cases.contains(.connection))
        #expect(cases.contains(.custom))
    }

    @Test func accentColorSourceDisplayNames() {
        #expect(AccentColorSource.system.displayName == "System")
        #expect(AccentColorSource.connection.displayName == "Connection")
        #expect(AccentColorSource.custom.displayName == "Custom")
    }

    @Test func accentColorSourceRawValues() {
        #expect(AccentColorSource.system.rawValue == "system")
        #expect(AccentColorSource.connection.rawValue == "connection")
        #expect(AccentColorSource.custom.rawValue == "custom")
    }

    @Test func accentColorSourceCodableRoundTrip() throws {
        for source in AccentColorSource.allCases {
            let data = try JSONEncoder().encode(source)
            let decoded = try JSONDecoder().decode(AccentColorSource.self, from: data)
            #expect(decoded == source)
        }
    }

    // MARK: - NativePsqlRuntimePreference

    @Test func nativePsqlRuntimePreferenceAllCases() {
        let cases = NativePsqlRuntimePreference.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.bundled))
        #expect(cases.contains(.system))
    }

    @Test func nativePsqlRuntimePreferenceDisplayNames() {
        #expect(NativePsqlRuntimePreference.bundled.displayName == "Bundled Binary")
        #expect(NativePsqlRuntimePreference.system.displayName == "System Binary")
    }

    @Test func nativePsqlRuntimePreferenceCodableRoundTrip() throws {
        for pref in NativePsqlRuntimePreference.allCases {
            let data = try JSONEncoder().encode(pref)
            let decoded = try JSONDecoder().decode(NativePsqlRuntimePreference.self, from: data)
            #expect(decoded == pref)
        }
    }

    // MARK: - SidebarAutoExpandSection: displayName

    @Test func sidebarAutoExpandSectionDisplayNames() {
        #expect(SidebarAutoExpandSection.databases.displayName == "Databases")
        #expect(SidebarAutoExpandSection.tables.displayName == "Tables")
        #expect(SidebarAutoExpandSection.views.displayName == "Views")
        #expect(SidebarAutoExpandSection.materializedViews.displayName == "Materialized Views")
        #expect(SidebarAutoExpandSection.functions.displayName == "Functions")
        #expect(SidebarAutoExpandSection.procedures.displayName == "Procedures")
        #expect(SidebarAutoExpandSection.triggers.displayName == "Triggers")
        #expect(SidebarAutoExpandSection.management.displayName == "Management")
        #expect(SidebarAutoExpandSection.security.displayName == "Security")
    }

    // MARK: - SidebarAutoExpandSection: objectType mapping

    @Test func sidebarAutoExpandSectionObjectTypeMapping() {
        #expect(SidebarAutoExpandSection.tables.objectType == .table)
        #expect(SidebarAutoExpandSection.views.objectType == .view)
        #expect(SidebarAutoExpandSection.materializedViews.objectType == .materializedView)
        #expect(SidebarAutoExpandSection.functions.objectType == .function)
        #expect(SidebarAutoExpandSection.procedures.objectType == .procedure)
        #expect(SidebarAutoExpandSection.triggers.objectType == .trigger)
        #expect(SidebarAutoExpandSection.databases.objectType == nil)
        #expect(SidebarAutoExpandSection.management.objectType == nil)
        #expect(SidebarAutoExpandSection.security.objectType == nil)
    }

    // MARK: - SidebarAutoExpandSection: generalSections

    @Test func sidebarAutoExpandSectionGeneralSections() {
        let general = SidebarAutoExpandSection.generalSections
        #expect(general.contains(.databases))
        #expect(general.contains(.tables))
        #expect(general.contains(.views))
        #expect(general.contains(.functions))
        #expect(general.contains(.triggers))
        #expect(!general.contains(.materializedViews))
        #expect(!general.contains(.procedures))
        #expect(!general.contains(.management))
        #expect(!general.contains(.security))
    }

    // MARK: - SidebarAutoExpandSection: uniqueSections

    @Test func sidebarAutoExpandSectionUniqueSectionsPostgresql() {
        let unique = SidebarAutoExpandSection.uniqueSections(for: .postgresql)
        #expect(unique.contains(.materializedViews))
        #expect(unique.contains(.security))
        #expect(!unique.contains(.procedures))
        #expect(!unique.contains(.management))
    }

    @Test func sidebarAutoExpandSectionUniqueSectionsMSSQL() {
        let unique = SidebarAutoExpandSection.uniqueSections(for: .microsoftSQL)
        #expect(unique.contains(.procedures))
        #expect(unique.contains(.management))
        #expect(unique.contains(.security))
        #expect(!unique.contains(.materializedViews))
    }

    @Test func sidebarAutoExpandSectionUniqueSectionsMySQL() {
        let unique = SidebarAutoExpandSection.uniqueSections(for: .mysql)
        #expect(unique.contains(.procedures))
        #expect(!unique.contains(.materializedViews))
        #expect(!unique.contains(.management))
        #expect(!unique.contains(.security))
    }

    @Test func sidebarAutoExpandSectionUniqueSectionsSQLite() {
        let unique = SidebarAutoExpandSection.uniqueSections(for: .sqlite)
        #expect(unique.isEmpty)
    }

    // MARK: - SidebarAutoExpandSection: allSections

    @Test func sidebarAutoExpandSectionAllSectionsPostgresql() {
        let all = SidebarAutoExpandSection.allSections(for: .postgresql)
        #expect(all.contains(.databases))
        #expect(all.contains(.tables))
        #expect(all.contains(.views))
        #expect(all.contains(.functions))
        #expect(all.contains(.triggers))
        #expect(all.contains(.materializedViews))
        #expect(all.contains(.security))
    }

    @Test func sidebarAutoExpandSectionAllSectionsMSSQL() {
        let all = SidebarAutoExpandSection.allSections(for: .microsoftSQL)
        #expect(all.contains(.databases))
        #expect(all.contains(.tables))
        #expect(all.contains(.views))
        #expect(all.contains(.functions))
        #expect(all.contains(.triggers))
        #expect(all.contains(.procedures))
        #expect(all.contains(.management))
        #expect(all.contains(.security))
    }

    @Test func sidebarAutoExpandSectionAllSectionsSQLite() {
        let all = SidebarAutoExpandSection.allSections(for: .sqlite)
        #expect(all.contains(.databases))
        #expect(all.contains(.tables))
        #expect(all.contains(.views))
        // SQLite doesn't support functions or triggers in the schema
        #expect(!all.contains(.procedures))
        #expect(!all.contains(.materializedViews))
    }

    // MARK: - SidebarAutoExpandSection: id

    @Test func sidebarAutoExpandSectionIdMatchesRawValue() {
        for section in SidebarAutoExpandSection.allCases {
            #expect(section.id == section.rawValue)
        }
    }

    // MARK: - ResultGridColorOverrides: Codable round-trip

    @Test func resultGridColorOverridesCodableRoundTrip() throws {
        var overrides = ResultGridColorOverrides()
        overrides.nullHex = "FF0000"
        overrides.numericHex = "00FF00"
        overrides.booleanHex = "0000FF"
        overrides.temporalHex = "FFFF00"
        overrides.binaryHex = "FF00FF"
        overrides.identifierHex = "00FFFF"
        overrides.jsonHex = "888888"
        overrides.textHex = "AABBCC"

        let data = try JSONEncoder().encode(overrides)
        let decoded = try JSONDecoder().decode(ResultGridColorOverrides.self, from: data)

        #expect(decoded.nullHex == "FF0000")
        #expect(decoded.numericHex == "00FF00")
        #expect(decoded.booleanHex == "0000FF")
        #expect(decoded.temporalHex == "FFFF00")
        #expect(decoded.binaryHex == "FF00FF")
        #expect(decoded.identifierHex == "00FFFF")
        #expect(decoded.jsonHex == "888888")
        #expect(decoded.textHex == "AABBCC")
    }

    @Test func resultGridColorOverridesDefaultNils() {
        let overrides = ResultGridColorOverrides()
        #expect(overrides.nullHex == nil)
        #expect(overrides.numericHex == nil)
        #expect(overrides.booleanHex == nil)
        #expect(overrides.temporalHex == nil)
        #expect(overrides.binaryHex == nil)
        #expect(overrides.identifierHex == nil)
        #expect(overrides.jsonHex == nil)
        #expect(overrides.textHex == nil)
    }

    // MARK: - GlobalSettings: Codable round-trip

    @Test func globalSettingsCodableRoundTripPreservesAllFields() throws {
        var settings = GlobalSettings()
        settings.appearanceMode = .dark
        settings.defaultEditorFontSize = 16.0
        settings.defaultEditorFontFamily = "Menlo"
        settings.editorShowLineNumbers = false
        settings.editorHighlightSelectedSymbol = false
        settings.editorHighlightDelay = 0.5
        settings.editorWrapLines = false
        settings.editorIndentWrappedLines = 8
        settings.editorEnableAutocomplete = false
        settings.editorQualifyTableCompletions = true
        settings.editorSuggestKeywords = false
        settings.editorEnableInlineSuggestions = false
        settings.editorSuggestFunctions = false
        settings.editorSuggestSnippets = false
        settings.editorSuggestHistory = false
        settings.editorSuggestJoins = false
        settings.editorShowSystemSchemas = true
        settings.editorAllowCommandPeriodTrigger = false
        settings.editorAllowControlSpaceTrigger = false
        settings.accentColorSource = .custom
        settings.customAccentColorHex = "FF5500"
        settings.resultsAlternateRowShading = true
        settings.resultsShowRowNumbers = false
        settings.resultsEnableTypeFormatting = false
        settings.showForeignKeysInInspector = false
        settings.showJsonInInspector = false
        settings.resultsInitialRowLimit = 1000
        settings.resultsPreviewBatchSize = 1000
        settings.autoOpenInspectorOnSelection = false
        settings.keepTabsInMemory = true
        settings.showSavedConnectionsInExplorer = true
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandSections = [.databases, .tables]
        settings.sidebarAutoExpandPostgresql = [.databases, .materializedViews]
        settings.sidebarAutoExpandSQLServer = [.databases, .procedures]
        settings.nativePsqlEnabled = true
        settings.nativePsqlRuntimePreference = .system
        settings.nativePsqlAllowSystemBinaryFallback = true
        settings.nativePsqlAllowShellEscape = false
        settings.nativePsqlAllowFileCommands = false
        settings.sidebarIconColorMode = .monochrome
        settings.managedPostgresConsoleEnabled = false

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        #expect(decoded.appearanceMode == .dark)
        #expect(decoded.defaultEditorFontSize == 16.0)
        #expect(decoded.defaultEditorFontFamily == "Menlo")
        #expect(decoded.editorShowLineNumbers == false)
        #expect(decoded.editorHighlightSelectedSymbol == false)
        #expect(decoded.editorHighlightDelay == 0.5)
        #expect(decoded.editorWrapLines == false)
        #expect(decoded.editorIndentWrappedLines == 8)
        #expect(decoded.editorEnableAutocomplete == false)
        #expect(decoded.editorQualifyTableCompletions == true)
        #expect(decoded.editorSuggestKeywords == false)
        #expect(decoded.editorEnableInlineSuggestions == false)
        #expect(decoded.editorSuggestFunctions == false)
        #expect(decoded.editorSuggestSnippets == false)
        #expect(decoded.editorSuggestHistory == false)
        #expect(decoded.editorSuggestJoins == false)
        #expect(decoded.editorShowSystemSchemas == true)
        #expect(decoded.editorAllowCommandPeriodTrigger == false)
        #expect(decoded.editorAllowControlSpaceTrigger == false)
        #expect(decoded.accentColorSource == .custom)
        #expect(decoded.customAccentColorHex == "FF5500")
        #expect(decoded.resultsAlternateRowShading == true)
        #expect(decoded.resultsShowRowNumbers == false)
        #expect(decoded.resultsEnableTypeFormatting == false)
        #expect(decoded.showForeignKeysInInspector == false)
        #expect(decoded.showJsonInInspector == false)
        #expect(decoded.resultsInitialRowLimit == 1000)
        #expect(decoded.resultsPreviewBatchSize == 1000)
        #expect(decoded.autoOpenInspectorOnSelection == false)
        #expect(decoded.keepTabsInMemory == true)
        #expect(decoded.showSavedConnectionsInExplorer == true)
        #expect(decoded.sidebarCustomizePerDatabaseType == true)
        #expect(decoded.sidebarAutoExpandSections == [.databases, .tables])
        #expect(decoded.sidebarAutoExpandPostgresql == [.databases, .materializedViews])
        #expect(decoded.sidebarAutoExpandSQLServer == [.databases, .procedures])
        #expect(decoded.nativePsqlEnabled == true)
        #expect(decoded.nativePsqlRuntimePreference == .system)
        #expect(decoded.nativePsqlAllowSystemBinaryFallback == true)
        #expect(decoded.nativePsqlAllowShellEscape == false)
        #expect(decoded.nativePsqlAllowFileCommands == false)
        #expect(decoded.sidebarIconColorMode == .monochrome)
        #expect(decoded.managedPostgresConsoleEnabled == false)
    }

    // MARK: - Legacy migration: useServerColorAsAccent -> accentColorSource

    @Test func legacyMigrationUseServerColorTrueBecomesConnection() throws {
        let json: [String: Any] = [
            "useServerColorAsAccent": true
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        #expect(decoded.accentColorSource == .connection)
    }

    @Test func legacyMigrationUseServerColorFalseBecomesSystem() throws {
        let json: [String: Any] = [
            "useServerColorAsAccent": false
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        #expect(decoded.accentColorSource == .system)
    }

    @Test func legacyMigrationAccentColorSourceOverridesLegacyBool() throws {
        let json: [String: Any] = [
            "useServerColorAsAccent": true,
            "accentColorSource": "custom"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        #expect(decoded.accentColorSource == .custom)
    }

    @Test func legacyMigrationNeitherKeyDefaultsToConnection() throws {
        let json: [String: Any] = [:]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        // Default legacy behavior: useServerColorAsAccent defaults to true -> .connection
        #expect(decoded.accentColorSource == .connection)
    }

    // MARK: - sidebarExpandSections(for:)

    @Test func sidebarExpandSectionsDefaultFallsBackToGeneral() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = false
        settings.sidebarAutoExpandSections = [.databases, .tables]

        let result = settings.sidebarExpandSections(for: .postgresql)
        #expect(result.contains(.databases))
        #expect(result.contains(.tables))
    }

    @Test func sidebarExpandSectionsFiltersToRelevant() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = false
        // procedures is not in postgresql's allSections
        settings.sidebarAutoExpandSections = [.databases, .procedures]

        let result = settings.sidebarExpandSections(for: .postgresql)
        #expect(result.contains(.databases))
        #expect(!result.contains(.procedures))
    }

    @Test func sidebarExpandSectionsUsesPerTypeOverridePostgresql() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandPostgresql = [.materializedViews]

        let result = settings.sidebarExpandSections(for: .postgresql)
        #expect(result == [.materializedViews])
    }

    @Test func sidebarExpandSectionsUsesPerTypeOverrideMSSQL() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandSQLServer = [.procedures, .management]

        let result = settings.sidebarExpandSections(for: .microsoftSQL)
        #expect(result == [.procedures, .management])
    }

    @Test func sidebarExpandSectionsUsesPerTypeOverrideMySQL() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandMySQL = [.tables]

        let result = settings.sidebarExpandSections(for: .mysql)
        #expect(result == [.tables])
    }

    @Test func sidebarExpandSectionsSQLiteFallsBackNoOverride() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandSections = [.databases, .tables]

        // No SQLite-specific override exists
        let result = settings.sidebarExpandSections(for: .sqlite)
        #expect(result.contains(.databases))
        #expect(result.contains(.tables))
    }

    @Test func sidebarExpandSectionsPerTypeNilFallsBackToGeneral() {
        var settings = GlobalSettings()
        settings.sidebarCustomizePerDatabaseType = true
        settings.sidebarAutoExpandPostgresql = nil // no override set
        settings.sidebarAutoExpandSections = [.databases]

        let result = settings.sidebarExpandSections(for: .postgresql)
        #expect(result.contains(.databases))
    }

    // MARK: - ligaturesEnabled(for:)

    @Test func ligaturesEnabledDefaultsToTrue() {
        let settings = GlobalSettings()
        #expect(settings.ligaturesEnabled(for: "JetBrainsMono-Regular") == true)
        #expect(settings.ligaturesEnabled(for: "Fira Code") == true)
        #expect(settings.ligaturesEnabled(for: "UnknownFont") == true)
    }

    @Test func ligaturesEnabledRespectsOverride() {
        var settings = GlobalSettings()
        settings.fontLigatureOverrides = [
            "JetBrainsMono-Regular": false,
            "Fira Code": true
        ]

        #expect(settings.ligaturesEnabled(for: "JetBrainsMono-Regular") == false)
        #expect(settings.ligaturesEnabled(for: "Fira Code") == true)
        #expect(settings.ligaturesEnabled(for: "Other") == true) // not in overrides
    }

    // MARK: - defaultPalette(for:)

    @Test func defaultPaletteReturnsBuiltInForLight() {
        let settings = GlobalSettings()
        let palette = settings.defaultPalette(for: .light)
        #expect(palette != nil)
        #expect(palette?.id == settings.defaultEditorPaletteIDLight)
    }

    @Test func defaultPaletteReturnsBuiltInForDark() {
        let settings = GlobalSettings()
        let palette = settings.defaultPalette(for: .dark)
        #expect(palette != nil)
        #expect(palette?.id == settings.defaultEditorPaletteIDDark)
    }

    @Test func defaultPaletteReturnsNilForUnknownID() {
        var settings = GlobalSettings()
        settings.defaultEditorPaletteIDLight = "nonexistent-palette-id-12345"
        let palette = settings.defaultPalette(for: .light)
        #expect(palette == nil)
    }

    @Test func defaultPalettePrefersCustomOverBuiltIn() {
        var settings = GlobalSettings()
        // Create a custom palette by copying a built-in one with a custom ID
        guard let builtIn = SQLEditorTokenPalette.builtIn.first else {
            Issue.record("No built-in palettes available")
            return
        }
        var customPalette = builtIn.asCustomCopy(named: "My Custom")
        let customID = customPalette.id
        settings.customEditorPalettes = [customPalette]
        settings.defaultEditorPaletteIDLight = customID

        let palette = settings.defaultPalette(for: .light)
        #expect(palette?.id == customID)
        #expect(palette?.name == "My Custom")
    }
}
