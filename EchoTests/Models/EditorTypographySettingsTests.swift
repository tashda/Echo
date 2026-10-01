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
    }

    @Test func oldDefaultsMoveToTheNewOnesOnce() throws {
        let settings = try decode { json in
            json.removeValue(forKey: "editorTypographyRevision")
            json["defaultEditorFontSize"] = 12.0
            json["defaultEditorLineHeight"] = 1.0
        }
        #expect(settings.defaultEditorFontSize == 13)
        #expect(settings.defaultEditorLineHeight == 1.55)
        #expect(settings.editorTypographyRevision == 1)
    }

    @Test func chosenValuesSurviveTheMove() throws {
        let settings = try decode { json in
            json.removeValue(forKey: "editorTypographyRevision")
            json["defaultEditorFontSize"] = 15.0
            json["defaultEditorLineHeight"] = 1.2
        }
        #expect(settings.defaultEditorFontSize == 15)
        #expect(settings.defaultEditorLineHeight == 1.2)
    }

    @Test func twelvePointChosenAfterTheMoveStays() throws {
        let settings = try decode { json in
            json["editorTypographyRevision"] = 1
            json["defaultEditorFontSize"] = 12.0
            json["defaultEditorLineHeight"] = 1.0
        }
        #expect(settings.defaultEditorFontSize == 12)
        #expect(settings.defaultEditorLineHeight == 1)
    }

    @Test(arguments: [("subtle", EditorGutterStyle.subtle), ("tinted", .tinted), ("lane", .lane), ("unknown", .subtle)])
    func gutterStyleDecodes(raw: String, expected: EditorGutterStyle) throws {
        let settings = try decode { $0["editorGutterStyle"] = raw }
        #expect(settings.editorGutterStyle == expected)
    }

    @Test func bundledFontsHaveDisplayNames() {
        #expect(SQLEditorTheme.bundledFontFamilies.contains(SQLEditorTheme.defaultFontFamily))
        #expect(SQLEditorTheme.bundledFontDisplayNames["CommitMono"] == "Commit Mono")
        #expect(SQLEditorTheme.bundledFontDisplayNames.keys.allSatisfy(SQLEditorTheme.bundledFontFamilies.contains))
    }
}
