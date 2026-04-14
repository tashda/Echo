import Testing
@testable import Echo

@Suite("BottomPanelState")
struct BottomPanelStateTests {
    @Test func queryTabHasResultsAndMessages() {
        let state = BottomPanelState.forQueryTab()

        #expect(state.availableSegments.contains(.results))
        #expect(state.availableSegments.contains(.messages))
    }

    @Test func queryTabHasConditionalPanels() {
        let state = BottomPanelState.forQueryTab()

        #expect(state.availableSegments.contains(.executionPlan))
        #expect(state.availableSegments.contains(.spatial))
    }

    @Test func queryTabDoesNotIncludeRemovedPanels() {
        let state = BottomPanelState.forQueryTab()

        #expect(!state.availableSegments.contains(.textResults))
        #expect(!state.availableSegments.contains(.verticalResults))
        #expect(!state.availableSegments.contains(.statistics))
        #expect(!state.availableSegments.contains(.tuning))
        #expect(!state.availableSegments.contains(.history))
    }

    @Test func queryTabPermanentPanelsAreFirst() {
        let state = BottomPanelState.forQueryTab()

        // Results and Messages should be the first two segments
        #expect(state.availableSegments[0] == .results)
        #expect(state.availableSegments[1] == .messages)
    }
}
