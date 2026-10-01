import SwiftUI

extension ConnectionStore {
    /// A server's colour as saved now. An open session keeps the copy of its connection it was
    /// opened with, so a colour changed since (from the header's menu, round 30.1) is read here.
    func currentColor(of connection: SavedConnection) -> Color {
        connections.first { $0.id == connection.id }?.color ?? connection.color
    }
}
