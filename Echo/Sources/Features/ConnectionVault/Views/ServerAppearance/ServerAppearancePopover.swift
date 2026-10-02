import SwiftUI

/// The popover of the trail's Customize Appearance (round 51, WH2). It edits a copy of the
/// server's colour and glyph and saves each change at once, so the trail shows it as it is picked.
struct ServerAppearancePopover: View {
    let connection: SavedConnection

    @Environment(ConnectionStore.self) private var connectionStore
    @Environment(EnvironmentState.self) private var environmentState
    @State private var colorHex: String
    @State private var glyph: ServerRailGlyph?

    init(connection: SavedConnection) {
        self.connection = connection
        _colorHex = State(initialValue: connection.colorHex)
        _glyph = State(initialValue: connection.railGlyph)
    }

    var body: some View {
        ServerAppearanceControls(name: displayName, colorHex: $colorHex, glyph: $glyph)
            .padding(SpacingTokens.md)
            .frame(width: ServerAppearanceMetrics.popoverWidth)
            .onChange(of: colorHex) { _, _ in save() }
            .onChange(of: glyph) { _, _ in save() }
    }

    private var displayName: String {
        let trimmed = connection.connectionName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? connection.host : trimmed
    }

    private func save() {
        let connectionID = connection.id
        let colorHex = colorHex
        let glyph = glyph
        Task {
            do {
                try await connectionStore.updateAppearance(of: connectionID, colorHex: colorHex, glyph: glyph)
            } catch {
                environmentState.notificationEngine?.post(category: .generalError, message: "The server's appearance couldn't be saved: \(error.localizedDescription)")
            }
        }
    }
}
