import CoreGraphics

enum ObjectBrowserConnectionLayoutMode: Equatable {
    case singleConnection
    case multipleConnections

    init(expandOneConnectionAtATime: Bool) {
        self = expandOneConnectionAtATime ? .singleConnection : .multipleConnections
    }

    /// In single-connection mode pending connections live in the server rail only.
    var includesPendingConnectionsInOutline: Bool {
        self == .multipleConnections
    }

    var showsServerNameInOutline: Bool {
        self == .multipleConnections
    }

    /// Kept minimal so the first server card lines up with the top of the rail.
    var outlineTopSpacerHeight: CGFloat {
        SpacingTokens.micro
    }
}
