import CoreGraphics
import Foundation

/// Round 57 (CK1): where the tree scrolls to when a card's dock section is chosen. Each card
/// remembers, per section, how far into the card the view was when it left that section; choosing
/// the section scrolls back to that place, or to the card's top the first time. Kept for the
/// session only, and dropped when the server leaves the tree.
nonisolated struct ExplorerDockPlaces: Equatable, Sendable {
    private var places: [Key: CGFloat] = [:]

    private struct Key: Hashable, Sendable {
        let connectionID: UUID
        let section: String
    }

    /// Remembers how far into the card the view was in `section` (never below zero).
    mutating func save(_ scrolledInCard: CGFloat, connectionID: UUID, section: String) {
        places[Key(connectionID: connectionID, section: section)] = max(scrolledInCard, 0)
    }

    func place(connectionID: UUID, section: String) -> CGFloat? {
        places[Key(connectionID: connectionID, section: section)]
    }

    /// A server left the tree: its cards' places are gone.
    mutating func drop(keeping connectionIDs: Set<UUID>) {
        places = places.filter { connectionIDs.contains($0.key.connectionID) }
    }

    /// Where the view scrolls to when `section` is chosen, or nil when it stays put.
    /// - The remembered place, clamped to what the section's content allows (`maxOffset`).
    /// - With none (a first visit) or a place of zero: the card's top, but only when the view is
    ///   scrolled into the card; a card still below the top of the view doesn't move it.
    func target(connectionID: UUID, section: String, cardTop: CGFloat, offset: CGFloat, maxOffset: CGFloat) -> CGFloat? {
        let remembered = place(connectionID: connectionID, section: section) ?? 0
        let wanted: CGFloat
        if remembered > 0 {
            wanted = cardTop + remembered
        } else if offset > cardTop + Self.tolerance {
            wanted = cardTop
        } else {
            return nil
        }
        let y = min(max(wanted, 0), max(maxOffset, 0))
        return abs(y - offset) > Self.tolerance ? y : nil
    }

    /// Less than this is the same place.
    static let tolerance: CGFloat = 0.5
}
