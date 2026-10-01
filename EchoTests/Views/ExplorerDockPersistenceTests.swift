import Foundation
import Testing
@testable import Echo

/// Round 16: a server's own dock is saved on its connection, each type's in Settings.
@Suite("Explorer dock persistence")
struct ExplorerDockPersistenceTests {
    @Test func aServersDockSurvivesSaving() throws {
        var connection = TestFixtures.savedConnection(databaseType: .microsoftSQL)
        connection.explorerDockSections = ["agentJobs", "databases"]
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONEncoder().encode(connection))
        #expect(decoded.explorerDockSections == ["agentJobs", "databases"])
    }

    @Test func aConnectionSavedBeforeTheDockFollowsItsType() throws {
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(TestFixtures.savedConnection())) as? [String: Any])
        object.removeValue(forKey: "explorerDockSections")
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.explorerDockSections == nil)
    }

    @Test func eachTypesDockAndTheIconStyleSurviveSaving() throws {
        var settings = GlobalSettings()
        settings.sidebarDockSections = [DatabaseType.postgresql.rawValue: ["databases", "activity"]]
        settings.sidebarDockIconStyle = .duotone
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.sidebarDockSections == settings.sidebarDockSections)
        #expect(decoded.sidebarDockIconStyle == .duotone)
    }

    @Test func theDockIconsAreMonoByDefault() {
        #expect(GlobalSettings().sidebarDockIconStyle == .mono)
        #expect(GlobalSettings().sidebarDockSections.isEmpty)
    }
}
