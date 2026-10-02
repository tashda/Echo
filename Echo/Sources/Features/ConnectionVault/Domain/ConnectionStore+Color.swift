import SwiftUI

extension ConnectionStore {
    /// A server's colour as saved now. An open session keeps the copy of its connection it was
    /// opened with, so a colour changed since (from the header's menu, round 30.1) is read here.
    func currentColor(of connection: SavedConnection) -> Color {
        connections.first { $0.id == connection.id }?.color ?? connection.color
    }

    /// The colour as saved (a hex), read here for the same reason, so the header can tell a light
    /// colour from a dark one in the current appearance.
    func currentColorHex(of connection: SavedConnection) -> String {
        connections.first { $0.id == connection.id }?.colorHex ?? connection.colorHex
    }

    /// A server's symbol or emoji as saved now, read here for the same reason as the colour.
    func currentGlyph(of connection: SavedConnection) -> ServerRailGlyph? {
        (connections.first { $0.id == connection.id } ?? connection).railGlyph
    }

    /// Saves the colour and the symbol or emoji the user chose for a server (round 51, WH2).
    func updateAppearance(of connectionID: UUID, colorHex: String, glyph: ServerRailGlyph?) async throws {
        guard var connection = connections.first(where: { $0.id == connectionID }) else { return }
        connection.colorHex = colorHex
        connection.railGlyph = glyph
        try await updateConnection(connection)
    }
}
