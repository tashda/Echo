import SwiftUI

enum InspectorTab: CaseIterable {
    case dataInspector
    case notifications

    var icon: String {
        switch self {
        case .dataInspector: return "tablecells"
        case .notifications: return "bell"
        }
    }

    var activeIcon: String {
        switch self {
        case .dataInspector: return "tablecells.fill"
        case .notifications: return "bell.fill"
        }
    }

    var title: String {
        switch self {
        case .dataInspector: return "Data Inspector"
        case .notifications: return "Notifications"
        }
    }
}

enum InspectorLayout {
    static let horizontalPadding: CGFloat = 12
}
