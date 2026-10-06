import Foundation
import Testing
@testable import Echo

@Suite("Closed card destination")
struct ClosedCardDestinationTests {
    @Test func settingsSavedBeforeTheSettingExistedUseTheServerTrail() throws {
        let data = try JSONEncoder().encode(GlobalSettings())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "closedCardDestination")
        let old = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: old)

        #expect(decoded.closedCardDestination == .serverTrail)
    }

    @Test func theChoiceSurvivesSavingAndLoading() throws {
        var settings = GlobalSettings()
        settings.closedCardDestination = .headerCard

        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONEncoder().encode(settings))

        #expect(decoded.closedCardDestination == .headerCard)
    }
}
