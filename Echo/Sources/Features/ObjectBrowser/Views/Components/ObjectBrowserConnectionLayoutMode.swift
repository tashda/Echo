import CoreGraphics

enum ObjectBrowserConnectionLayoutMode: Equatable {
    case singleConnection
    case multipleConnections

    init(expandOneConnectionAtATime: Bool) {
        self = expandOneConnectionAtATime ? .singleConnection : .multipleConnections
    }

    var showsConnectionDock: Bool {
        self == .singleConnection
    }

    var includesPendingConnectionsInOutline: Bool {
        self == .multipleConnections
    }

    var showsServerNameInOutline: Bool {
        self == .multipleConnections
    }

    func outlineTopSpacerHeight(connectionDockHeight: CGFloat) -> CGFloat {
        switch self {
        case .singleConnection:
            return max(connectionDockHeight, SpacingTokens.none) + SpacingTokens.xs
        case .multipleConnections: return SpacingTokens.xs
        }
    }
}
