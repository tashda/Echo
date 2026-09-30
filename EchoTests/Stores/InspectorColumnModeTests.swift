import Testing
@testable import Echo

@Suite("Inspector column: details and notifications")
@MainActor
struct InspectorColumnModeTests {
    @Test func bellShowsTheHistoryInTheColumn() {
        let state = AppState()
        state.isNotificationHistoryVisible = true
        #expect(state.isInspectorColumnVisible)
        #expect(!state.showInfoSidebar)
    }

    @Test func inspectorButtonSwitchesFromHistoryToDetails() {
        let state = AppState()
        state.isNotificationHistoryVisible = true
        state.toggleInspector()
        #expect(state.showInfoSidebar)
        #expect(!state.isNotificationHistoryVisible)
        state.toggleInspector()
        #expect(!state.isInspectorColumnVisible)
    }

    @Test func askingForDetailsPutsTheHistoryAway() {
        let state = AppState()
        state.isNotificationHistoryVisible = true
        state.showInfoSidebar = true
        #expect(!state.isNotificationHistoryVisible)
    }

    @Test func closingTheHistoryReturnsToTheDetails() {
        let state = AppState()
        state.showInfoSidebar = true
        state.isNotificationHistoryVisible = true
        state.isNotificationHistoryVisible = false
        #expect(state.isInspectorColumnVisible)
    }
}
