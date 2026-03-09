import XCTest
@testable import Echo

final class GlobalSettingsTests: XCTestCase {

    // MARK: - Codable Round-Trip

    func testCodableRoundTrip() throws {
        var settings = GlobalSettings()
        settings.defaultEditorFontSize = 14.0
        settings.editorShowLineNumbers = false
        settings.resultsInitialRowLimit = 1000
        settings.diagramPrefetchMode = .full

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertEqual(decoded.defaultEditorFontSize, 14.0)
        XCTAssertEqual(decoded.editorShowLineNumbers, false)
        XCTAssertEqual(decoded.resultsInitialRowLimit, 1000)
        XCTAssertEqual(decoded.diagramPrefetchMode, .full)
    }

    // MARK: - Legacy Migration

    func testLegacyPaletteIDMigration() throws {
        let json: [String: Any] = [
            "defaultEditorPaletteID": "custom-palette-123"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertEqual(decoded.defaultEditorPaletteIDLight, "custom-palette-123")
        XCTAssertEqual(decoded.defaultEditorPaletteIDDark, "custom-palette-123")
    }

    func testNewPaletteIDsOverrideLegacy() throws {
        let json: [String: Any] = [
            "defaultEditorPaletteID": "old-palette",
            "defaultEditorPaletteIDLight": "light-palette",
            "defaultEditorPaletteIDDark": "dark-palette"
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertEqual(decoded.defaultEditorPaletteIDLight, "light-palette")
        XCTAssertEqual(decoded.defaultEditorPaletteIDDark, "dark-palette")
    }

    // MARK: - Init Clamping

    func testResultsInitialRowLimitClampsToMinimum() throws {
        let json: [String: Any] = [
            "resultsInitialRowLimit": 10
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertGreaterThanOrEqual(decoded.resultsInitialRowLimit, 100)
    }

    func testResultsPreviewBatchSizeClampsToMinimum() throws {
        let json: [String: Any] = [
            "resultsPreviewBatchSize": 5
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertGreaterThanOrEqual(decoded.resultsPreviewBatchSize, 100)
    }

    func testDiagramCacheMaxBytesClampsToMinimum() throws {
        let json: [String: Any] = [
            "diagramCacheMaxBytes": 1024
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: data)

        XCTAssertGreaterThanOrEqual(decoded.diagramCacheMaxBytes, 64 * 1_024 * 1_024)
    }

    // MARK: - Default Values

    func testDefaultValues() {
        let settings = GlobalSettings()

        XCTAssertEqual(settings.editorShowLineNumbers, true)
        XCTAssertEqual(settings.editorHighlightSelectedSymbol, true)
        XCTAssertEqual(settings.editorWrapLines, true)
        XCTAssertEqual(settings.editorEnableAutocomplete, true)
        XCTAssertEqual(settings.resultsInitialRowLimit, 500)
        XCTAssertEqual(settings.resultSpoolMaxBytes, 5 * 1_024 * 1_024 * 1_024)
        XCTAssertEqual(settings.resultSpoolRetentionHours, 72)
        XCTAssertEqual(settings.diagramPrefetchMode, .off)
        XCTAssertEqual(settings.diagramRefreshCadence, .never)
        XCTAssertEqual(settings.keepTabsInMemory, false)
        XCTAssertEqual(settings.useServerColorAsAccent, true)
    }
}
