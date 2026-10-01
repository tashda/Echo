import SwiftUI

extension EnvironmentValues {
    /// How tall the footer floating over the bottom of a card is, so the content under it
    /// (the results grid, the editor, a message list) can scroll clear of it and blur beneath it
    /// (round 9, FB1).
    @Entry var cardFooterOverlayHeight: CGFloat = 0

    /// How much of the content card's bottom is clipped away while the panel grows or folds:
    /// the card is laid out at one height and only its clip moves, so something pinned to the
    /// card's bottom adds this to stay on the visible edge (owner, after round 31).
    @Entry var cardHiddenBottom: CGFloat = 0

    /// Whether the footer rests in the content card once the panel's current motion ends: it
    /// changes as the panel starts to fold or grow, with that motion.
    @Entry var cardFooterRestsInCard = false
}
