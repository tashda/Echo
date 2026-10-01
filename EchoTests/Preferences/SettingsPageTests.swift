import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Settings search and reset (round 43)")
struct SettingsPageTests {
    @Test func searchFindsASettingByAWordOfItsTitle() {
        let titles = SettingsSearchIndex.matches(for: "gutter").map(\.title)
        #expect(titles.contains("Gutter Style"))
        #expect(titles.contains("Line Numbers"))
    }

    @Test func searchNeedsEveryWord() {
        let titles = SettingsSearchIndex.matches(for: "mark corners").map(\.title)
        #expect(titles == ["Mark Corners"])
        #expect(SettingsSearchIndex.matches(for: "   ").isEmpty)
    }

    @Test func searchAlsoFindsPages() {
        let hit = SettingsSearchIndex.matches(for: "Appearance").first { $0.group == "Page" }
        #expect(hit?.section == .appearance)
    }

    @Test func everyEntryPointsAtARealGroupName() {
        for entry in SettingsSearchIndex.entries {
            #expect(!entry.group.isEmpty && !entry.title.isEmpty)
        }
    }

    @Test func resettingAPageRestoresOnlyItsSettings() {
        var settings = GlobalSettings()
        settings.editorGutterStyle = .lane
        settings.editorMarkCorners = .square
        settings.resultsShowRowNumbers.toggle()
        let defaults = GlobalSettings()
        for setting in EditorSettingsView.resettable { setting.apply(&settings, defaults) }
        #expect(settings.editorGutterStyle == defaults.editorGutterStyle)
        #expect(settings.editorMarkCorners == defaults.editorMarkCorners)
        #expect(settings.resultsShowRowNumbers != defaults.resultsShowRowNumbers)
    }
}
