import Foundation
import Testing
@testable import Echo

/// Dragging a tab along the strip when the tabs differ in width: a tool tab showing its pages is
/// wider than the tabs around it (round 49), and the others make room by its own width.
@Suite("Dragging a tab along the strip")
struct TabDragStateTests {
    private func drag(from index: Int, widths: [CGFloat]) -> TabDragState {
        var state = TabDragState()
        state.begin(id: UUID(), originalIndex: index, minIndex: 0, maxIndex: widths.count - 1, widths: widths)
        return state
    }

    @Test func equalTabsSwapPastSixtyPercentOfTheNeighbour() {
        let state = drag(from: 1, widths: [100, 100, 100, 100])
        #expect(state.proposedIndex(for: 59) == 1)
        #expect(state.proposedIndex(for: 61) == 2)
        #expect(state.proposedIndex(for: 159) == 2)
        #expect(state.proposedIndex(for: 161) == 3)
        #expect(state.proposedIndex(for: -61) == 0)
    }

    @Test func aWideToolTabPassesANarrowNeighbourByThatNeighboursWidth() {
        // The tool tab (600) between two icon-only tabs (40).
        let state = drag(from: 1, widths: [40, 600, 40])
        #expect(state.proposedIndex(for: 23) == 1)
        #expect(state.proposedIndex(for: 25) == 2)
        #expect(state.proposedIndex(for: -25) == 0)
    }

    @Test func aNarrowTabNeedsMostOfAWideNeighbourBeforeItSwaps() {
        let state = drag(from: 0, widths: [40, 600, 40])
        #expect(state.proposedIndex(for: 359) == 0)
        #expect(state.proposedIndex(for: 361) == 1)
    }

    @Test func passedTabsMoveByTheDraggedTabsWidth() {
        var state = drag(from: 1, widths: [40, 600, 40, 40])
        state.currentIndex = 3
        state.translation = 80
        #expect(state.offset(forTabAt: 1) == 80)
        #expect(state.offset(forTabAt: 2) == -600)
        #expect(state.offset(forTabAt: 3) == -600)
        #expect(state.offset(forTabAt: 0) == 0)

        state.currentIndex = 0
        #expect(state.offset(forTabAt: 0) == 600)
        #expect(state.offset(forTabAt: 2) == 0)
    }

    @Test func theTranslationStopsAtTheEndsOfTheStrip() {
        let state = drag(from: 1, widths: [40, 600, 40, 40])
        #expect(state.clamped(500) == 80)
        #expect(state.clamped(-500) == -40)
        #expect(state.clamped(30) == 30)
    }

    @Test func pinnedBoundsKeepTheTabInItsGroup() {
        var state = TabDragState()
        state.begin(id: UUID(), originalIndex: 2, minIndex: 2, maxIndex: 3, widths: [40, 40, 100, 100])
        #expect(state.clamped(-500) == 0)
        #expect(state.proposedIndex(for: -500) == 2)
    }

    @Test func nothingMovesWithoutADrag() {
        #expect(TabDragState().offset(forTabAt: 0) == 0)
    }
}
