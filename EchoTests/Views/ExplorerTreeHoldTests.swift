import CoreGraphics
import Testing
@testable import Echo

/// Round 19, N2: the view never scrolls back by itself when the list gets shorter.
@Suite("Explorer tree hold")
struct ExplorerTreeHoldTests {
    @Test func aShorterListKeepsTheBottomWhereItWas() {
        // Scrolled to 600 in a 400pt view of a 1000pt list; the list shrinks to 700.
        #expect(ExplorerTreeHold.spacerHeight(offset: 600, viewport: 400, contentHeight: 700, previousTotal: 1000) == 300)
    }

    @Test func aListThatStillReachesTheBottomNeedsNoSpacer() {
        #expect(ExplorerTreeHold.spacerHeight(offset: 100, viewport: 400, contentHeight: 900, previousTotal: 1000) == 0)
    }

    @Test func scrollingUpGivesTheRoomBack() {
        #expect(ExplorerTreeHold.spacerHeight(offset: 450, viewport: 400, contentHeight: 700, previousTotal: 1000) == 150)
    }

    @Test func overscrollingCannotStretchIt() {
        // Pulled 200pt past the bottom of a 1000pt list: the spacer stays at what the list needs.
        #expect(ExplorerTreeHold.spacerHeight(offset: 800, viewport: 400, contentHeight: 700, previousTotal: 1000) == 300)
    }
}
