import Testing
@testable import Echo

@Suite("Inspector column: details and notifications")
@MainActor
struct InspectorColumnModeTests {
    @Test func bellShowsTheHistoryInTheColumn() {
        let state = AppState()
        state.toggleNotificationHistory()
        #expect(state.isInspectorColumnVisible)
        #expect(!state.showInfoSidebar)
    }

    @Test func inspectorButtonSwitchesFromHistoryToDetails() {
        let state = AppState()
        state.toggleNotificationHistory()
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

    @Test func bellFromTheDetailsSwitchesThenClosesTheColumn() {
        let state = AppState()
        state.toggleInspector()
        state.toggleNotificationHistory()
        #expect(state.isNotificationHistoryVisible && !state.showInfoSidebar)
        state.toggleNotificationHistory()
        #expect(!state.isInspectorColumnVisible)
    }
}
