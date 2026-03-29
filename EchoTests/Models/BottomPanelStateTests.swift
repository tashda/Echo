import Testing
@testable import Echo

@Suite("BottomPanelState")
struct BottomPanelStateTests {
    @Test func queryTabIncludesWorkbenchResultModes() {
        let state = BottomPanelState.forQueryTab()

        #expect(state.availableSegments.contains(.results))
        #expect(state.availableSegments.contains(.textResults))
        #expect(state.availableSegments.contains(.verticalResults))
        #expect(state.availableSegments.contains(.statistics))
    }

    @Test func panelSegmentLabelsCoverStatisticsModes() {
        #expect(PanelSegment.textResults.label == "Text")
        #expect(PanelSegment.verticalResults.label == "Vertical")
        #expect(PanelSegment.statistics.label == "Statistics")
    }
}
