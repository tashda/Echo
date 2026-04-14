import Foundation
import SwiftUI

// MARK: - Server Switcher Data

@MainActor
struct ServerSwitcherItem: Identifiable {
    let id: UUID
    let session: ConnectionSession
    let isActive: Bool

    var displayName: String { session.displayName }
    var shortName: String { session.shortDisplayName }
    var queryTabCount: Int { session.queryTabs.count }
    var connectionColor: Color { session.connection.color }
    var lastActivity: Date { session.lastActivity }
}
