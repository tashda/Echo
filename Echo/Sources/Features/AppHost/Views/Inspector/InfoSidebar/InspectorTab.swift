import SwiftUI

enum InspectorTab: CaseIterable {
    case dataInspector
    case connection

    var icon: String {
        switch self {
        case .dataInspector: return "tablecells"
        case .connection: return "server.rack"
        }
    }

    var activeIcon: String {
        switch self {
        case .dataInspector: return "tablecells.fill"
        case .connection: return "server.rack"
        }
    }

    var title: String {
        switch self {
        case .dataInspector: return "Data Inspector"
        case .connection: return "Connection"
        }
    }
}

enum InspectorLayout {
    static let horizontalPadding: CGFloat = 12
}
