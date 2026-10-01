import CoreGraphics
import Foundation

/// A node the Explorer tree can lay out. Echo's tree and Echo Labs' specimens both conform, so
/// Echo Labs draws the tree with the same layout, cards, veil and motion as Echo.
@MainActor
public protocol ExplorerTreeNode {
    var id: String { get }
    var children: [Self] { get }
    /// What the layout needs to know about the node's row.
    var treeRole: ExplorerTreeRole { get }
}

/// The part of a row the tree's layout depends on: its kind, which server and database it
/// belongs to, and how much taller than a plain row its slot is.
public struct ExplorerTreeRole: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The gap above a server's card.
        case spacer(CGFloat)
        /// A server's name row; starts a card.
        case server
        /// A server still connecting; starts a card.
        case pendingConnection
        /// The section dock under a server's name, with the section it shows.
        case dock(selectedID: String)
        /// A server-level heading (Databases, Security…): its children start at the card's edge.
        case section
        /// A table column: carries no database of its own.
        case column
        /// Loading placeholders that take this many row slots.
        case loading(slots: Int)
        /// Any other row.
        case row
    }

    public var kind: Kind
    public var connectionID: UUID?
    public var databaseName: String?
    /// Extra height over a plain row (the server name's two lines, the dock's capsule…).
    public var extraSlotHeight: CGFloat

    public init(kind: Kind, connectionID: UUID? = nil, databaseName: String? = nil, extraSlotHeight: CGFloat = 0) {
        self.kind = kind
        self.connectionID = connectionID
        self.databaseName = databaseName
        self.extraSlotHeight = extraSlotHeight
    }

    public var isSpacer: Bool {
        if case .spacer = kind { return true }
        return false
    }

    /// A server or connecting server: the row that starts a card.
    public var startsCard: Bool {
        switch kind {
        case .server, .pendingConnection: true
        default: false
        }
    }
}

/// What sits at the top of the Explorer's visible area.
public struct ExplorerTreeTopContext: Equatable, Sendable {
    public var connectionID: UUID?
    public var databaseName: String?
    /// True once the server's own header has scrolled out of view.
    public var isScrolledPastServerHeader: Bool

    public init(connectionID: UUID? = nil, databaseName: String? = nil, isScrolledPastServerHeader: Bool) {
        self.connectionID = connectionID
        self.databaseName = databaseName
        self.isScrolledPastServerHeader = isScrolledPastServerHeader
    }
}
