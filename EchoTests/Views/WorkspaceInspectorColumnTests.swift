import Testing
@testable import Echo

@Suite("Inspector column width")
@MainActor
struct WorkspaceInspectorColumnTests {
    @Test func keepsTheChosenWidthWithinLimits() {
        #expect(WorkspaceInspectorColumn.displayedWidth(chosen: 340, isJson: false) == 340)
        #expect(WorkspaceInspectorColumn.displayedWidth(chosen: 10, isJson: false) == LayoutTokens.Inspector.minWidth)
        #expect(WorkspaceInspectorColumn.displayedWidth(chosen: 10_000, isJson: false) == LayoutTokens.Inspector.maxWidth)
    }

    @Test func jsonWidensButNeverNarrows() {
        #expect(WorkspaceInspectorColumn.displayedWidth(chosen: 300, isJson: true) == LayoutTokens.Inspector.jsonWidth)
        #expect(WorkspaceInspectorColumn.displayedWidth(chosen: 600, isJson: true) == 600)
    }
}
