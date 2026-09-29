import Foundation
import Testing
@testable import Echo

@MainActor
@Suite("Design Lab tab selection")
struct LabRound13TabSelectionTests {
    @Test func closingInactiveTabKeepsSelection() {
        let active = UUID()
        let closed = UUID()
        #expect(LabRound13TabSelection.activeID(
            afterClosing: closed,
            previousActiveID: active,
            closedIndex: 0,
            remainingIDs: [active]
        ) == active)
    }

    @Test func closingSelectedTabChoosesItsNextNeighbor() {
        let first = UUID()
        let closed = UUID()
        let next = UUID()
        #expect(LabRound13TabSelection.activeID(
            afterClosing: closed,
            previousActiveID: closed,
            closedIndex: 1,
            remainingIDs: [first, next]
        ) == next)
    }

    @Test func closingLastSelectedTabChoosesPreviousNeighbor() {
        let previous = UUID()
        let closed = UUID()
        #expect(LabRound13TabSelection.activeID(
            afterClosing: closed,
            previousActiveID: closed,
            closedIndex: 1,
            remainingIDs: [previous]
        ) == previous)
    }
}
