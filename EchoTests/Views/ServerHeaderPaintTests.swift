import Foundation
import SwiftUI
import Testing
@testable import Echo

/// Round 30.1: the server header's style and colour, the dock's current icon, and where the
/// server's colour also shows.
@MainActor
@Suite("Server header paint")
struct ServerHeaderPaintTests {
    private let server = Color.red
    private let accent = Color.blue

    @Test func defaultsAreTheWashInTheServersColorWithTheDockInIt() {
        let settings = GlobalSettings()
        #expect(settings.serverHeaderStyle == .wash)
        #expect(settings.serverHeaderColorSource == .server)
        #expect(settings.sidebarDockCurrentIconTint == .header)
        let paint = ServerHeaderPaint(settings: settings, serverColor: server, accent: accent)
        #expect(paint.color == server)
        #expect(paint.dockColor == server)
        #expect(paint.marksServer)
    }

    @Test func noColorLeavesTheDockOnTheAccentAndMarksNothing() {
        let paint = ServerHeaderPaint(style: .wash, source: .none, dockTint: .header, serverColor: server, accent: accent)
        #expect(paint.color == nil)
        #expect(paint.dockColor == accent)
        #expect(!paint.marksServer)
    }

    @Test func accentColorPaintsTheHeaderButDoesNotMarkTheServer() {
        let paint = ServerHeaderPaint(style: .banner, source: .accent, dockTint: .header, serverColor: server, accent: accent)
        #expect(paint.color == accent)
        #expect(!paint.marksServer)
        #expect(paint.isOnFill)
    }

    @Test func theDockCanStayOnTheAccent() {
        let paint = ServerHeaderPaint(style: .plain, source: .server, dockTint: .accent, serverColor: server, accent: accent)
        #expect(paint.dockColor == accent)
        #expect(!paint.isOnFill)
    }

    @Test func settingsWithoutTheNewKeysDecodeToTheDefaults() throws {
        let data = try JSONEncoder().encode(GlobalSettings())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "serverHeaderStyle")
        object.removeValue(forKey: "serverHeaderColorSource")
        object.removeValue(forKey: "sidebarDockCurrentIconTint")
        // Settings removed since (rounds 30.3 and 40) are ignored when an older file is read.
        object["sidebarShowsEmptyFolders"] = true
        object["collapsedServerClick"] = "peekCommandReopens"
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.serverHeaderStyle == .wash)
        #expect(decoded.serverHeaderColorSource == .server)
        #expect(decoded.sidebarDockCurrentIconTint == .header)
    }

    @Test func eachChoiceRoundTrips() throws {
        var settings = GlobalSettings()
        settings.serverHeaderStyle = .plate
        settings.serverHeaderColorSource = .none
        settings.sidebarDockCurrentIconTint = .accent
        let decoded = try JSONDecoder().decode(GlobalSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.serverHeaderStyle == .plate)
        #expect(decoded.serverHeaderColorSource == .none)
        #expect(decoded.sidebarDockCurrentIconTint == .accent)
    }
}
