import Testing
@testable import Echo

/// Round 28.8: the editor's zoom steps (ZR0).
@Suite("Editor zoom")
struct EditorZoomTests {
    @Test func stepsMoveThroughTheLevelsAndStopAtTheEnds() {
        #expect(EditorZoom.step(1, by: 1) == 1.1)
        #expect(EditorZoom.step(1, by: -1) == 0.9)
        #expect(EditorZoom.step(2, by: 1) == 2)
        #expect(EditorZoom.step(0.5, by: -1) == 0.5)
        #expect(EditorZoom.step(1.2, by: 1) == 1.25)
    }

    @Test func labelsArePercentages() {
        #expect(EditorZoom.label(1) == "100%")
        #expect(EditorZoom.label(1.25) == "125%")
    }

    /// Round 31 (ZW1, ZN2): with results the pill sits 9pt up, like the footer's pills; with the
    /// footer in the editor's card it stacks above the server pill, 9pt between.
    @Test @MainActor func thePillSitsLikeTheFooterPills() {
        #expect(EditorZoomControl.bottomInset(footerInCard: false) == LayoutTokens.Footer.pillInset)
        #expect(EditorZoomControl.bottomInset(footerInCard: true) == 42)
        #expect(EditorZoomControl.leadingInset == 12)
    }

    /// While the results fold, the editor card is laid out at its final height and only its clip
    /// moves; the pill rides on the visible edge.
    @Test @MainActor func thePillRidesOnTheVisibleEdge() {
        #expect(EditorZoomControl.bottomInset(footerInCard: true, hiddenBelow: 200) == 242)
    }
}
