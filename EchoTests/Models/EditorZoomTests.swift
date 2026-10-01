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
}
