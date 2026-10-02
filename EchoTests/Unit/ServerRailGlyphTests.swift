import AppKit
import Foundation
import Testing
@testable import Echo

/// A server's own symbol or emoji in the trail (round 51, CU2): the saved fields, older data and
/// synced copies, and what the controls offer.
@MainActor
struct ServerRailGlyphTests {
    private func connection() -> SavedConnection {
        SavedConnection(connectionName: "tippr", host: "tippr.local", port: 5432, database: "tippr", username: "tippr")
    }

    @Test func noFieldsMeansAutomatic() {
        #expect(ServerRailGlyph(symbol: nil, emoji: nil) == nil)
        #expect(ServerRailGlyph(symbol: "  ", emoji: "") == nil)
    }

    @Test func aSymbolWinsOverAnEmoji() {
        #expect(ServerRailGlyph(symbol: "flame.fill", emoji: "🔥") == .symbol("flame.fill"))
        #expect(ServerRailGlyph(symbol: nil, emoji: "🔥") == .emoji("🔥"))
    }

    @Test func settingOneKindClearsTheOther() {
        var saved = connection()
        saved.railGlyph = .symbol("bolt.fill")
        #expect(saved.railSymbol == "bolt.fill" && saved.railEmoji == nil)
        saved.railGlyph = .emoji("🚀")
        #expect(saved.railSymbol == nil && saved.railEmoji == "🚀")
        saved.railGlyph = nil
        #expect(saved.railSymbol == nil && saved.railEmoji == nil)
    }

    @Test func dataSavedBeforeTheFieldsExistDecodesAsAutomatic() throws {
        let data = try JSONEncoder().encode(connection())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["railSymbol"] == nil && object["railEmoji"] == nil)
        object.removeValue(forKey: "railSymbol")
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.railGlyph == nil)
    }

    @Test func aChosenGlyphSurvivesSaving() throws {
        var saved = connection()
        saved.railGlyph = .emoji("🧪")
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONEncoder().encode(saved))
        #expect(decoded.railGlyph == .emoji("🧪"))
    }

    @Test func aWrongTypedFieldDoesNotLoseTheConnection() throws {
        let data = try JSONEncoder().encode(connection())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["railSymbol"] = 42
        let decoded = try JSONDecoder().decode(SavedConnection.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(decoded.railGlyph == nil)
        #expect(decoded.connectionName == "tippr")
    }

    @Test func syncCarriesTheGlyphAndOlderCopiesLeaveItAlone() throws {
        let adapter = SyncAdapter()
        var saved = connection()
        saved.railGlyph = .symbol("leaf.fill")
        let document = try adapter.toSyncDocument(saved, hlc: 1)
        #expect(try adapter.applyToConnection(document, existing: nil).railGlyph == .symbol("leaf.fill"))

        // A copy synced from an Echo that has no such fields keeps what is set here.
        var older = document
        older.fields.removeValue(forKey: "railSymbol")
        older.fields.removeValue(forKey: "railEmoji")
        #expect(try adapter.applyToConnection(older, existing: saved).railGlyph == .symbol("leaf.fill"))
    }

    @Test func everyOfferedSymbolExists() {
        for name in ServerRailGlyph.symbols {
            #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name) is not an SF Symbol")
        }
        #expect(Set(ServerRailGlyph.symbols).count == ServerRailGlyph.symbols.count)
        #expect(Set(ServerRailGlyph.emoji).count == ServerRailGlyph.emoji.count)
    }
}
