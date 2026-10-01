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

@Suite("Unguarded writes and settings sync (round 43.5)")
struct UnguardedWriteTests {
    @Test func flagsUpdateAndDeleteWithoutWhere() {
        #expect(UnguardedWriteDetector.unguardedStatements(in: "update t set a = 1").count == 1)
        #expect(UnguardedWriteDetector.unguardedStatements(in: "DELETE FROM t; select 1").count == 1)
    }

    @Test func aWhereClearsIt() {
        #expect(UnguardedWriteDetector.unguardedStatements(in: "update t set a = 1 where id = 2").isEmpty)
        #expect(UnguardedWriteDetector.unguardedStatements(in: "delete from t\nWHERE id = 1;").isEmpty)
    }

    @Test func commentsAndQuotedTextDontCount() {
        #expect(UnguardedWriteDetector.unguardedStatements(in: "update t set a = 'x where y' -- where\n").count == 1)
        #expect(UnguardedWriteDetector.unguardedStatements(in: "update t set a = 1 /* no */ where id = 1").isEmpty)
        #expect(UnguardedWriteDetector.unguardedStatements(in: "select * from t where a = 'delete from t'").isEmpty)
    }

    @Test func settingsSyncKeepsEachMacsOwnPaths() {
        var local = GlobalSettings()
        local.pgToolCustomPath = "/Users/me/pg"
        local.resultSpoolCustomLocation = "/Volumes/fast"
        var remote = GlobalSettings()
        remote.editorGutterStyle = .lane
        remote.pgToolCustomPath = "/Users/other/pg"

        #expect(local.withoutThisMacsValues().pgToolCustomPath == nil)
        #expect(local.withoutThisMacsValues().resultSpoolCustomLocation == nil)
        let merged = remote.keepingThisMacsValues(from: local)
        #expect(merged.editorGutterStyle == .lane)
        #expect(merged.pgToolCustomPath == "/Users/me/pg")
        #expect(merged.resultSpoolCustomLocation == "/Volumes/fast")
    }
}
