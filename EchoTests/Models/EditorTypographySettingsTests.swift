import Foundation
import Testing
@testable import Echo

@Suite("Editor typography and gutter settings")
struct EditorTypographySettingsTests {
    /// Encodes default settings, then edits the JSON the way an older build would have saved it.
    private func decode(_ edit: (inout [String: Any]) -> Void) throws -> GlobalSettings {
        let data = try JSONEncoder().encode(GlobalSettings())
        var json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        edit(&json)
        return try JSONDecoder().decode(GlobalSettings.self, from: JSONSerialization.data(withJSONObject: json))
    }

    @Test func newSettingsUseThirteenPointAndWiderSpacing() {
        let settings = GlobalSettings()
        #expect(settings.defaultEditorFontSize == 13)
        #expect(settings.defaultEditorLineHeight == 1.55)
        #expect(settings.defaultEditorFontFamily == SQLEditorTheme.systemFontIdentifier)
        #expect(settings.editorSelectionCornerRadius == 3)
        #expect(!settings.ligaturesEnabled(for: settings.defaultEditorFontFamily))
    }

    @Test func oldDefaultsMoveToTheNewOnesOnce() throws {
        let settings = try decode { json in
            json.removeValue(forKey: "editorTypographyRevision")
            json["defaultEditorFontSize"] = 12.0
            json["defaultEditorLineHeight"] = 1.0
        }
        #expect(settings.defaultEditorFontSize == 13)
        #expect(settings.defaultEditorLineHeight == 1.55)
        #expect(settings.editorTypographyRevision == 2)
    }

    @Test func chosenValuesSurviveTheMove() throws {
        let settings = try decode { json in
            json.removeValue(forKey: "editorTypographyRevision")
            json["defaultEditorFontSize"] = 15.0
            json["defaultEditorLineHeight"] = 1.2
        }
        #expect(settings.defaultEditorFontSize == 15)
        // Round 28.1: a chosen spacing lands on its nearest name.
        #expect(settings.defaultEditorLineHeight == EditorLineHeight.compact.rawValue)
    }

    @Test(arguments: [(1.0, EditorLineHeight.compact), (1.2, .compact), (1.35, .comfortable), (1.55, .comfortable), (1.75, .relaxed), (2.0, .relaxed)])
    func oldSpacingsLandOnTheirNearestName(value: Double, expected: EditorLineHeight) {
        #expect(EditorLineHeight.nearest(to: value) == expected)
    }

    @Test func theOldDefaultFontMovesToSFMonoOnce() throws {
        let moved = try decode { json in
            json["editorTypographyRevision"] = 1
            json["defaultEditorFontFamily"] = "JetBrainsMono-Regular"
        }
        #expect(moved.defaultEditorFontFamily == SQLEditorTheme.systemFontIdentifier)
        let chosenLater = try decode { json in
            json["editorTypographyRevision"] = 2
            json["defaultEditorFontFamily"] = "JetBrainsMono-Regular"
        }
        #expect(chosenLater.defaultEditorFontFamily == "JetBrainsMono-Regular")
        let other = try decode { json in
            json["editorTypographyRevision"] = 1
            json["defaultEditorFontFamily"] = "Geist Mono"
        }
        #expect(other.defaultEditorFontFamily == "Geist Mono")
    }

    @Test func selectionCornersDecodeAndDefault() throws {
        #expect(try decode { _ = $0.removeValue(forKey: "editorSelectionCornerRadius") }.editorSelectionCornerRadius == 3)
        #expect(try decode { $0["editorSelectionCornerRadius"] = 6.0 }.editorSelectionCornerRadius == 6)
    }

    /// Round 28.11 (TH1): only Aurora and Midnight are left; a removed palette falls back to them.
    @Test func removedPalettesFallBackToAuroraAndMidnight() throws {
        #expect(SQLEditorPalette.builtIn.map(\.id) == [SQLEditorPalette.aurora.id, SQLEditorPalette.midnight.id])
        let settings = try decode { json in
            json["defaultEditorPaletteIDLight"] = "solstice"
            json["defaultEditorPaletteIDDark"] = "dracula"
        }
        #expect(settings.defaultEditorPaletteIDLight == SQLEditorPalette.aurora.id)
        #expect(settings.defaultEditorPaletteIDDark == SQLEditorPalette.midnight.id)
    }

    @Test func highlightCornersDecodeAndDefault() throws {
        #expect(GlobalSettings().editorHighlightCornerRadius == 3)
        #expect(try decode { $0["editorHighlightCornerRadius"] = 0.0 }.editorHighlightCornerRadius == 0)
    }

    /// Round 28.11 (FS1): whole sizes, “13 pt”.
    @MainActor @Test func fontSizesAreWholePoints() {
        #expect(EditorSettingsView.fontSizeOptions.allSatisfy { $0.rounded() == $0 })
        #expect(EditorSettingsView.fontSizeLabel(13) == "13 pt")
    }

    @Test func aLineIsTheMultipleOfTheSizeNeverLessThanTheFont() {
        #expect(SQLLayoutManager.lineHeight(fontSize: 13, multiple: 1.55, naturalHeight: 16) == 20)
        #expect(SQLLayoutManager.lineHeight(fontSize: 13, multiple: 1.75, naturalHeight: 16) == 23)
        #expect(SQLLayoutManager.lineHeight(fontSize: 13, multiple: 1.0, naturalHeight: 17) == 17)
    }

    @Test func twelvePointChosenAfterTheMoveStays() throws {
        let settings = try decode { json in
            json["editorTypographyRevision"] = 1
            json["defaultEditorFontSize"] = 12.0
            json["defaultEditorLineHeight"] = 1.0
        }
        #expect(settings.defaultEditorFontSize == 12)
        #expect(settings.defaultEditorLineHeight == EditorLineHeight.compact.rawValue)
    }

    @Test(arguments: [("subtle", EditorGutterStyle.subtle), ("tinted", .tinted), ("lane", .lane), ("hairline", .hairline), ("unknown", .subtle)])
    func gutterStyleDecodes(raw: String, expected: EditorGutterStyle) throws {
        let settings = try decode { $0["editorGutterStyle"] = raw }
        #expect(settings.editorGutterStyle == expected)
    }

    @Test func bundledFontsHaveDisplayNames() {
        #expect(SQLEditorTheme.bundledFontFamilies.contains("JetBrains Mono"))
        #expect(SQLEditorTheme.bundledFontDisplayNames["CommitMono"] == "Commit Mono")
        #expect(SQLEditorTheme.bundledFontDisplayNames.keys.allSatisfy(SQLEditorTheme.bundledFontFamilies.contains))
    }
}
